# frozen_string_literal: true

require 'active_support/concern'
require 'graphiform/helpers'
require 'graphiform/deferred'
require 'graphiform/resolver_cache'
require 'graphiform/preloader_source'
require 'graphiform/scope_composer'

module Graphiform
  module Core
    extend ActiveSupport::Concern

    included do
      include Graphiform::Deferred
    end

    module ClassMethods
      def graphql_type
        unless defined? @graphql_type
          local_demodulized_name = demodulized_name
          @graphql_type = Helpers.get_const_or_create(local_demodulized_name, ::Types) do
            Class.new(::Types::BaseObject) do
              graphql_name local_demodulized_name
            end
          end

          @graphql_type.class_eval do
            field_class Graphiform.configuration[:field_class] if Graphiform.configuration[:field_class].present?
          end
        end

        graphiform_drain_pending_specs!
        @graphql_type
      end

      def graphql_input
        unless defined? @graphql_input
          local_demodulized_name = demodulized_name
          @graphql_input = Helpers.get_const_or_create(local_demodulized_name, ::Inputs) do
            Class.new(::Inputs::BaseInput) do
              graphql_name "#{local_demodulized_name}Input"
              has_no_arguments(true)
            end
          end
          @graphql_input.class_eval do
            argument_class Graphiform.configuration[:argument_class] if Graphiform.configuration[:argument_class].present?
          end
        end

        graphiform_drain_pending_specs!
        @graphql_input
      end

      def graphql_filter
        unless defined? @filter
          local_demodulized_name = demodulized_name
          @filter = Helpers.get_const_or_create(local_demodulized_name, ::Inputs::Filters) do
            Class.new(::Inputs::Filters::BaseFilter) do
              graphql_name "#{local_demodulized_name}Filter"
              has_no_arguments(true)
            end
          end

          filter_class = @filter
          @filter.class_eval do
            argument_class Graphiform.configuration[:argument_class] if Graphiform.configuration[:argument_class].present?
            argument 'OR', -> { [filter_class] }, required: false
            argument 'AND', -> { [filter_class] }, required: false
          end
        end

        graphiform_drain_pending_specs!
        @filter
      end

      def graphql_sort
        unless defined? @graphql_sort
          local_demodulized_name = demodulized_name
          @graphql_sort = Helpers.get_const_or_create(local_demodulized_name, ::Inputs::Sorts) do
            Class.new(::Inputs::Sorts::BaseSort) do
              graphql_name "#{local_demodulized_name}Sort"
              has_no_arguments(true)
            end
          end
          @graphql_sort.class_eval do
            argument_class Graphiform.configuration[:argument_class] if Graphiform.configuration[:argument_class].present?
          end
        end

        graphiform_drain_pending_specs!
        @graphql_sort
      end

      def graphql_grouping
        unless defined? @graphql_grouping
          local_demodulized_name = demodulized_name
          @graphql_grouping = Helpers.get_const_or_create(local_demodulized_name, ::Inputs::Groupings) do
            Class.new(::Inputs::Groupings::BaseGrouping) do
              graphql_name "#{local_demodulized_name}Grouping"
              argument_class Graphiform.configuration[:argument_class] if Graphiform.configuration[:argument_class].present?
              has_no_arguments(true)
            end
          end
          @graphql_grouping.class_eval do
            argument_class Graphiform.configuration[:argument_class] if Graphiform.configuration[:argument_class].present?
          end
        end

        graphiform_drain_pending_specs!
        @graphql_grouping
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

      # ----------------------------------------------------------------------
      # Resolver classes: cached by signature so reload churn rebuilds them
      # only when the filter/sort/grouping/input/type shape actually changes.
      # ----------------------------------------------------------------------

      # Cheap signatures. Each reads a container that has already been drained
      # (the getters above call graphiform_drain_pending_specs!), so the
      # arguments/fields collections are stable for this build cycle.
      def graphql_type_signature
        graphql_type.fields.keys.sort.hash
      end

      def graphql_input_signature
        graphql_input.arguments.keys.sort.hash
      end

      def graphql_filter_signature
        graphql_filter.arguments.keys.sort.hash
      end

      def graphql_sort_signature
        graphql_sort.arguments.keys.sort.hash
      end

      def graphql_grouping_signature
        graphql_grouping.arguments.keys.sort.hash
      end

      def graphql_base_resolver
        # Drain before computing signatures.
        graphiform_drain_pending_specs!

        cache_key = [
          :base_resolver,
          object_id,
          graphql_filter_signature,
          graphql_sort_signature,
          graphql_grouping_signature,
        ]

        Graphiform::ResolverCache.fetch(cache_key) do
          model = self
          filter_thunk   = -> { model.graphql_filter }
          sort_thunk     = -> { model.graphql_sort }
          grouping_thunk = -> { model.graphql_grouping }

          klass = Class.new(::Resolvers::BaseResolver) do
            attr_reader :value

            class << self
              attr_accessor :addon_resolve_blocks
            end

            def self.addon_resolve(&block)
              @addon_resolve_blocks ||= []
              @addon_resolve_blocks << block
            end

            define_method(:model) { model }

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
              @value = Graphiform::ScopeComposer.compose(@value, where: where, sort: sort, group: group)
            end

            def base_resolve(**)
              object
            end

            argument :where, filter_thunk,   required: false
            argument :sort,  sort_thunk,     required: false
            argument :group, grouping_thunk, required: false
          end

          klass
        end
      end

      def graphql_query
        graphiform_drain_pending_specs!

        cache_key = [
          :query,
          object_id,
          graphql_filter_signature,
          graphql_sort_signature,
          graphql_grouping_signature,
          graphql_type_signature,
        ]

        Graphiform::ResolverCache.fetch(cache_key) do
          model = self
          type_thunk = -> { model.graphql_type }

          klass = Class.new(graphql_base_resolver) do
            type type_thunk, null: true

            def base_resolve(**args)
              @value = model.all
              apply_built_ins(**args)
              @value.take
            end
          end

          model.graphiform_query_specs[:arguments].each do |name, (type, opts)|
            next unless Helpers.seen_names_add?(klass, :arguments, name)
            klass.class_eval { argument(name, type, **opts) }
          end
          model.graphiform_query_specs[:class_evals].each_value do |b|
            klass.class_eval(&b)
          end
          model.graphiform_query_specs[:addon_resolves].each_value do |b|
            klass.addon_resolve(&b)
          end

          klass
        end
      end

      def graphql_connection_query
        graphiform_drain_pending_specs!

        cache_key = [
          :connection_query,
          object_id,
          graphql_filter_signature,
          graphql_sort_signature,
          graphql_grouping_signature,
          graphql_type_signature,
        ]

        Graphiform::ResolverCache.fetch(cache_key) do
          model = self
          connection_thunk = -> { model.graphql_connection }

          klass = Class.new(graphql_base_resolver) do
            type connection_thunk, null: false

            def base_resolve(**args)
              @value = model.all
              apply_built_ins(**args)
            end
          end

          model.graphiform_connection_query_specs[:arguments].each do |name, (type, opts)|
            next unless Helpers.seen_names_add?(klass, :arguments, name)

            klass.class_eval { argument(name, type, **opts) }
          end

          model.graphiform_connection_query_specs[:class_evals].each_value do |b|
            klass.class_eval(&b)
          end

          model.graphiform_connection_query_specs[:addon_resolves].each_value do |b|
            klass.addon_resolve(&b)
          end

          klass
        end
      end

      def graphql_create_resolver(
        method_name,
        resolver_type = nil,
        read_prepare: nil,
        read_resolve: nil,
        null: true,
        skip_dataloader: false,
        **
      )
        graphiform_drain_pending_specs!

        # Default the resolver type lazily so callers can omit it and the
        # type isn't materialized until the resolver is built.
        resolver_type ||= -> { graphql_type }

        # Cache key incorporates the inputs that determine the resolver's
        # shape and behavior. Blocks (read_prepare/read_resolve) are part of
        # the key via their source_location so edits invalidate.
        cache_key = [
          :association_resolver,
          object_id,
          method_name,
          # Resolver type: if it's a thunk, defer materialization; key on its
          # identity (object_id is stable for the lifetime of the thunk).
          resolver_type.respond_to?(:call) ? [:thunk, resolver_type.object_id] : resolver_type,
          read_prepare&.source_location,
          read_resolve&.source_location,
          null,
          skip_dataloader,
          graphql_filter_signature,
          graphql_sort_signature,
        ]

        Graphiform::ResolverCache.fetch(cache_key) do
          model = self
          captured_resolver_type = resolver_type
          captured_read_prepare = read_prepare
          captured_read_resolve = read_resolve
          captured_null = null
          captured_skip_dataloader = skip_dataloader
          captured_method_name = method_name

          Class.new(model.graphql_base_resolver) do
            type captured_resolver_type, null: captured_null

            define_method :base_resolve do |**args|
              @value = object
              association_def = @value.association(captured_method_name)&.reflection

              local_skip_dataloader = captured_skip_dataloader ||
                                      !association_def ||
                                      !Helpers.dataloader_support?(dataloader, association_def) ||
                                      captured_read_resolve ||
                                      captured_read_prepare ||
                                      args[:group]

              if local_skip_dataloader
                @value = instance_exec(@value, context, &captured_read_resolve) if captured_read_resolve
                @value = @value.public_send(captured_method_name) if !captured_read_resolve && @value.respond_to?(captured_method_name)
                @value = instance_exec(@value, context, &captured_read_prepare) if captured_read_prepare
                apply_built_ins(**args)
              else
                dataloader
                  .with(
                    Graphiform::PreloaderSource,
                    association_def.name,
                    klass: association_def.klass,
                    scope: association_def.scope,
                    where: args[:where],
                    sort: args[:sort],
                  )
                  .load(@value)
              end
            end
          end
        end
      end

      def graphql_create_association_resolver(association_def, resolver_type, null: true, skip_dataloader: false, **)
        cache_key = [
          :association_simple_resolver,
          object_id,
          association_def.name,
          association_def.klass.object_id,
          resolver_type.respond_to?(:call) ? [:thunk, resolver_type.object_id] : resolver_type,
          null,
          skip_dataloader,
        ]

        Graphiform::ResolverCache.fetch(cache_key) do
          captured_association_def = association_def
          captured_resolver_type = resolver_type
          captured_null = null
          captured_skip_dataloader = skip_dataloader

          Class.new(::Resolvers::BaseResolver) do
            type captured_resolver_type, null: captured_null

            define_method :resolve do |*|
              local_skip = captured_skip_dataloader ||
                           !Helpers.dataloader_support?(dataloader, captured_association_def)
              return object.public_send(captured_association_def.name) if local_skip

              dataloader.with(
                Graphiform::PreloaderSource,
                captured_association_def.name,
                klass: captured_association_def.klass,
                scope: captured_association_def.scope
              ).load(object)
            end
          end
        end
      end

      def graphql_create_method_resolver(method_name, resolver_type, null: true)
        cache_key = [
          :method_simple_resolver,
          object_id,
          method_name,
          resolver_type.respond_to?(:call) ? [:thunk, resolver_type.object_id] : resolver_type,
          null,
        ]
        Graphiform::ResolverCache.fetch(cache_key) do
          captured_method_name = method_name
          captured_resolver_type = resolver_type
          captured_null = null

          Class.new(::Resolvers::BaseResolver) do
            type captured_resolver_type, null: captured_null

            define_method :resolve do |*|
              object.public_send(captured_method_name)
            end
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