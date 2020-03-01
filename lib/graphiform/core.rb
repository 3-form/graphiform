# frozen_string_literal: true

require 'active_support/concern'

require 'graphiform/helpers'

module Graphiform
  module Core
    extend ActiveSupport::Concern

    module ClassMethods
      def graphql_type
        Helpers.get_const_or_create(demodulized_name, ::Types) do
          Class.new(::Types::BaseObject) do
            graphql_name demodulized_name
          end
        end
      end

      def graphql_input
        Helpers.get_const_or_create(demodulized_name, ::Inputs) do
          Class.new(::Inputs::BaseInput) do
            graphql_name "#{demodulized_name}Input"
          end
        end
      end

      def graphql_filter
        unless @filter
          @filter = Helpers.get_const_or_create(demodulized_name, ::Filters) do
            Class.new(::Filters::BaseFilter) do
              graphql_name "#{demodulized_name}Filter"
            end
          end
          @filter.class_eval do
            argument 'OR', [self], required: false
          end
        end

        @filter
      end

      def graphql_sorting_filter
        sorting_name = "#{demodulized_name}Sorting"
        Helpers.get_const_or_create(sorting_name, ::Filters) do
          Class.new(::Filters::BaseFilter) do
            graphql_name sorting_name
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
          node_type = graphql_type
          Class.new(::Types::BaseConnection) do
            graphql_name connection_name
            edge_type(node_type)
          end
        end
      end

      def graphql_base_resolver
        unless @base_resolver
          @base_resolver = Helpers.get_const_or_create(demodulized_name, ::Resolvers) do
            Class.new(::Resolvers::BaseResolver) do
              # Default resolver just returns the object to prevent exceptions
              define_method :resolve do |**_args|
                object
              end
            end
          end

          resolver_filter_type = graphql_filter
          resolver_sorting_type = graphql_sorting_filter

          @base_resolver.class_eval do
            argument :where, resolver_filter_type, required: false
            argument :order, resolver_sorting_type, required: false unless resolver_sorting_type.arguments.empty?
          end
        end

        @base_resolver
      end

      def graphql_connection_query
        Helpers.get_const_or_create(demodulized_name, ::ConnectionQueries) do
          model = self # TODO: I don't know if this will work or if it needs to be in upper scope
          connection_type = graphql_connection
          Class.new(graphql_base_resolver) do
            type connection_type, null: false

            define_method :resolve do |where: nil|
              val = model.all
              val = val.apply_filters(where.to_h) if where.present? && val.respond_to?(:apply_filters)

              val
            end
          end
        end
      end

      def graphql_create_resolver(method_name, resolver_type = graphql_type)
        Class.new(graphql_base_resolver) do
          type resolver_type, null: false

          define_method :resolve do |where: nil, **args|
            where_hash = where.to_h

            val = super(**args)

            val = val.public_send(method_name) if val.respond_to? method_name

            return val.apply_filters(where_hash) if val.respond_to? :apply_filters

            val
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
