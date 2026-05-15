# frozen_string_literal: true

require 'active_support/concern'

module Graphiform
  # Holds the queue of pending Graphiform DSL invocations on a model and
  # provides a one-time, re-entrant-safe drain that materializes them onto
  # the model's GraphQL containers (type, input, filter, sort, grouping).
  #
  # Why: in dev mode, model classes reload constantly. Doing field-definition
  # work inline in the class body means every reload re-runs that work and
  # cascades into associated models' definitions. By queueing the work and
  # draining it only when a GraphQL container is actually accessed, we avoid
  # paying that cost on every reload — we pay it once, lazily, the first
  # time the schema (or another model's thunk) touches this model's types.
  module Deferred
    extend ActiveSupport::Concern

    module ClassMethods
      # Public API used by Fields::ClassMethods (graphql_field, graphql_fields,
      # graphql_readable_field, etc.) to queue rather than execute.
      def graphiform_enqueue(method_name, args, kwargs, block = nil)
        graphiform_pending_specs << [method_name, args, kwargs, block]
        nil
      end

      # The queue itself. Reset on class reload because the class object is
      # replaced; that is the behavior we want.
      def graphiform_pending_specs
        @graphiform_pending_specs ||= []
      end

      # Drain all queued specs onto this model's containers exactly once per
      # batch of pending specs. Re-entrant: if a spec's execution triggers
      # another call to a getter (which calls drain again), we no-op.
      #
      # Note: we drain the *current* contents of the queue and clear them
      # before executing, so that any new specs added during execution (rare,
      # but possible via metaprogramming) end up in a fresh batch that will be
      # drained on the next access.
      def graphiform_drain_pending_specs!
        return if @graphiform_draining
        return if graphiform_pending_specs.empty?

        @graphiform_draining = true
        begin
          batch = @graphiform_pending_specs
          @graphiform_pending_specs = []

          batch.each do |method_name, args, kwargs, block|
            if block
              graphiform_execute_spec(method_name, args, kwargs, &block)
            else
              graphiform_execute_spec(method_name, args, kwargs)
            end
          end
        ensure
          @graphiform_draining = false
        end
      end

      private

      # Dispatch to the underlying immediate implementation. The immediate
      # methods live in Fields::ClassMethods as `graphql_field_now`,
      # `graphql_fields_now`, etc. (renamed from the original public methods).
      def graphiform_execute_spec(method_name, args, kwargs, &block)
        immediate = :"#{method_name}_now"
        if respond_to?(immediate, true)
          public_send(immediate, *args, **kwargs, &block)
        else
          # Defensive: should never hit this path; if a new DSL method is
          # added, the developer needs to add a corresponding `_now` impl.
          raise ArgumentError,
                "Graphiform::Deferred: no immediate implementation `#{immediate}` " \
                "for queued spec `#{method_name}` on `#{name}`"
        end
      end
    end
  end
end
