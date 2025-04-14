# frozen_string_literal: true

require 'active_support/concern'

require 'graphiform/helpers'
require 'graphiform/association_source'

module Graphiform
  module Core
    extend ActiveSupport::Concern

    module ClassMethods
      def graphql_type
        local_demodulized_name = demodulized_name
        Helpers.get_const_or_create(local_demodulized_name, ::Types) do
          Class.new(::Types::BaseObject) do
            graphql_name local_demodulized_name
          end
        end
      end

      def graphql_input
        local_demodulized_name = demodulized_name
        Helpers.get_const_or_create(local_demodulized_name, ::Inputs) do
          Class.new(::Inputs::BaseInput) do
            graphql_name "#{local_demodulized_name}Input"
          end
        end
      end

      def graphql_filter
        unless defined? @filter
          local_demodulized_name = demodulized_name
          @filter = Helpers.get_const_or_create(local_demodulized_name, ::Inputs::Filters) do
            Class.new(::Inputs::Filters::BaseFilter) do
              graphql_name "#{local_demodulized_name}Filter"
            end
          end
          @filter.class_eval do
            argument 'OR', [self], required: false
            argument 'AND', [self], required: false
          end
        end

        @filter
      end

      def graphql_sort
        local_demodulized_name = demodulized_name
        Helpers.get_const_or_create(local_demodulized_name, ::Inputs::Sorts) do
          Class.new(::Inputs::Sorts::BaseSort) do
            graphql_name "#{local_demodulized_name}Sort"
          end
        end
      end

      def graphql_grouping
        local_demodulized_name = demodulized_name
        Helpers.get_const_or_create(local_demodulized_name, ::Inputs::Groupings) do
          Class.new(::Inputs::Groupings::BaseGrouping) do
            graphql_name "#{local_demodulized_name}Grouping"
          end
        end
      end

      def graphql_edge
        Helpers.get_const_or_create("#{demodulized_name}Edge", ::Types) do
          node_type = graphql_type
          Class.new(::Types::BaseEdge) do
            node_type(node_type)
          end
        end
      end

      def graphql_connection
        connection_name = "#{demodulized_name}Connection"
        Helpers.get_const_or_create(connection_name, ::Types) do
          edge_type = graphql_edge
          Class.new(::Types::BaseConnection) do
            graphql_name connection_name
            edge_type(edge_type)
          end
        end
      end

      def graphql_base_resolver
        unless defined? @base_resolver
          @base_resolver = Helpers.get_const_or_create(demodulized_name, ::Resolvers) do
            Class.new(::Resolvers::BaseResolver) do
              attr_reader :value

              class << self
                attr_accessor :addon_resolve_blocks
              end

              def self.addon_resolve(&block)
                @addon_resolve_blocks ||= []
                @addon_resolve_blocks << block
              end

              def resolve(**args)
                @value = base_resolve(**args)

                if self.class.addon_resolve_blocks.present? && !self.class.addon_resolve_blocks.empty?
                  self.class.addon_resolve_blocks.each do |addon_resolve_block|
                    @value = instance_exec(**args, &addon_resolve_block)
                  end
                end

                @value
              end

              def apply_built_ins(where: nil, sort: nil, group: nil, **)
                @value = @value.apply_filters(where.to_h) if where.present? && @value.respond_to?(:apply_filters)
                @value = @value.apply_sorts(sort.to_h) if sort.present? && @value.respond_to?(:apply_sorts)
                @value = @value.apply_groupings(group.to_h) if group.present? && @value.respond_to?(:apply_groupings)

                @value
              end

              # Default resolver - meant to be overridden
              def base_resolve(**)
                object
              end
            end
          end

          local_graphql_filter = graphql_filter
          local_graphql_sort = graphql_sort
          local_graphql_grouping = graphql_grouping

          model = self
          @base_resolver.class_eval do
            unless respond_to?(:model)
              define_method :model do
                model
              end
            end

            argument :where, local_graphql_filter, required: false
            argument :sort, local_graphql_sort, required: false unless local_graphql_sort.arguments.empty?
            argument :group, local_graphql_grouping, required: false unless local_graphql_grouping.arguments.empty?
          end
        end

        @base_resolver
      end

      def graphql_query
        Helpers.get_const_or_create(demodulized_name, ::Resolvers::Queries) do
          local_graphql_type = graphql_type
          Class.new(graphql_base_resolver) do
            type local_graphql_type, null: true

            def base_resolve(**args)
              @value = model.all
              apply_built_ins(**args)
              @value.take
            end
          end
        end
      end

      def graphql_connection_query
        Helpers.get_const_or_create(demodulized_name, ::Resolvers::ConnectionQueries) do
          connection_type = graphql_connection
          Class.new(graphql_base_resolver) do
            type connection_type, null: false

            def base_resolve(**args)
              @value = model.all
              apply_built_ins(**args)
            end
          end
        end
      end

      def graphql_create_resolver(method_name, resolver_type = graphql_type, read_prepare: nil, read_resolve: nil, null: true, skip_dataloader: false, case_sensitive: Graphiform.configuration[:case_sensitive], **)
        Class.new(graphql_base_resolver) do
          type resolver_type, null: null

          define_method :base_resolve do |**args|
            @value = object

            association_def = @value.association(method_name)&.reflection

            skip_dataloader ||=
              !association_def ||
              !Helpers.dataloader_support?(dataloader, association_def, association_def.join_foreign_key) ||
              read_resolve ||
              read_prepare ||
              args[:group]

            if skip_dataloader
              @value = instance_exec(@value, context, &read_resolve) if read_resolve
              @value = @value.public_send(method_name) if !read_resolve && @value.respond_to?(method_name)
              @value = instance_exec(@value, context, &read_prepare) if read_prepare

              apply_built_ins(**args)
            else
              dataloader
                .with(
                  AssociationSource,
                  association_def.klass,
                  association_def.join_primary_key,
                  scope: association_def.scope,
                  where: args[:where],
                  sort: args[:sort],
                  multi: true,
                  case_sensitive: case_sensitive,
                )
                .load(
                  @value.public_send(association_def.join_foreign_key)
                )
            end
          end
        end
      end

      def graphql_create_association_resolver(association_def, resolver_type, null: true, skip_dataloader: false, case_sensitive: nil, **)
        Class.new(::Resolvers::BaseResolver) do
          type resolver_type, null: null

          define_method :resolve do |*|

            skip_dataloader ||= !Helpers.dataloader_support?(dataloader, association_def, association_def.join_foreign_key)

            return object.public_send(association_def.name) if skip_dataloader

            value = object.public_send(association_def.join_foreign_key)
            dataloader.with(AssociationSource, association_def.klass, association_def.join_primary_key, scope: association_def.scope, case_sensitive: case_sensitive).load(value)
          end
        end
      end

      def graphql_create_enum(enum_name)
        enum_name = enum_name.to_s
        enum_options = defined_enums[enum_name] || {}

        enum_class_name = "#{demodulized_name}#{enum_name.pluralize.capitalize}"
        Helpers.get_const_or_create(enum_class_name, ::Enums) do
          Class.new(::Enums::BaseEnum) do
            enum_options.each_key do |key|
              value key
            end
          end
        end
      end

      private

      def demodulized_name
        preferred_name.demodulize
      end
    end
  end
end
