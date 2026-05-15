# frozen_string_literal: true

require 'active_support/concern'

module Graphiform
  module Fields
    extend ActiveSupport::Concern

    module ClassMethods
      # ------------------------------------------------------------------
      # Public DSL — these enqueue rather than execute immediately.
      # The real work happens in the *_now counterparts during drain.
      # ------------------------------------------------------------------

      # arguments

      def graphql_filter_argument(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_filter_argument, args, kwargs, block)
      end

      def graphql_sort_argument(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_sort_argument, args, kwargs, block)
      end

      def graphql_query_argument(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_query_argument, args, kwargs, block)
      end

      def graphql_connection_query_argument(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_connection_query_argument, args, kwargs, block)
      end

      def graphql_grouping_argument(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_grouping_argument, args, kwargs, block)
      end

      def graphql_input_argument(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_input_argument, args, kwargs, block)
      end

      # fields

      def graphql_readable_field(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_readable_field, args, kwargs, block)
      end

      def graphql_writable_field(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_writable_field, args, kwargs, block)
      end

      def graphql_field(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_field, args, kwargs, block)
      end

      def graphql_fields(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_fields, args, kwargs, block)
      end

      def graphql_readable_fields(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_readable_fields, args, kwargs, block)
      end

      def graphql_writable_fields(*args, **kwargs, &block)
        graphiform_enqueue(:graphql_writable_fields, args, kwargs, block)
      end

      # class_evals

      def graphql_type_class_eval(&block)
        graphiform_enqueue(:graphql_type_class_eval, [], {}, block)
      end

      def graphql_filter_class_eval(&block)
        graphiform_enqueue(:graphql_filter_class_eval, [], {}, block)
      end

      def graphql_query_class_eval(&block)
        graphiform_enqueue(:graphql_query_class_eval, [], {}, block)
      end

      def graphql_sort_class_eval(&block)
        graphiform_enqueue(:graphql_sort_class_eval, [], {}, block)
      end

      def graphql_input_class_eval(&block)
        graphiform_enqueue(:graphql_input_class_eval, [], {}, block)
      end

      def graphql_grouping_class_eval(&block)
        graphiform_enqueue(:graphql_grouping_class_eval, [], {}, block)
      end

      def graphql_connection_query_class_eval(&block)
        graphiform_enqueue(:graphql_connection_query_class_eval, [], {}, block)
      end

      def graphql_connection_query_addon_resolve(&block)
        graphiform_enqueue(:graphql_connection_query_addon_resolve, [], {}, block)
      end

      # ------------------------------------------------------------------
      # Spec storage for query/connection_query — survives cache rebuilds.
      # ------------------------------------------------------------------

      def graphiform_query_specs
        @graphiform_query_specs ||= { arguments: {}, class_evals: {}, addon_resolves: {} }
      end

      def graphiform_connection_query_specs
        @graphiform_connection_query_specs ||= { arguments: {}, class_evals: {}, addon_resolves: {} }
      end

      # ------------------------------------------------------------------
      # Immediate implementations — called only from Deferred#drain.
      # ------------------------------------------------------------------

      def graphql_connection_query_addon_resolve_now(&block)
        key = block.source_location || [block.object_id]
        graphiform_connection_query_specs[:addon_resolves][key] = block
        graphql_connection_query.addon_resolve(&block)
      end

      def graphql_type_class_eval_now(&block)
        graphql_type.class_eval(&block)
      end

      def graphql_filter_class_eval_now(&block)
        graphql_filter.class_eval(&block)
      end

      def graphql_query_class_eval_now(&block)
        key = block.source_location || [block.object_id]
        graphiform_query_specs[:class_evals][key] = block
        graphql_query.class_eval(&block)
      end

      def graphql_sort_class_eval_now(&block)
        graphql_sort.class_eval(&block)
      end

      def graphql_input_class_eval_now(&block)
        graphql_input.class_eval(&block)
      end

      def graphql_grouping_class_eval_now(&block)
        graphql_grouping.class_eval(&block)
      end

      def graphql_connection_query_class_eval_now(&block)
        key = block.source_location || [block.object_id]
        graphiform_connection_query_specs[:class_evals][key] = block
        graphql_connection_query.class_eval(&block)
      end

      def graphql_filter_argument_now(name, type, **opts)
        return unless Helpers.seen_names_add?(graphql_filter, :arguments, name)

        graphql_filter.class_eval { argument(name, type, **opts) }
      end

      def graphql_sort_argument_now(name, type, **opts)
        return unless Helpers.seen_names_add?(graphql_sort, :arguments, name)

        graphql_sort.class_eval { argument(name, type, **opts) }
      end

      def graphql_query_argument_now(name, type, **opts)
        graphiform_query_specs[:arguments][name.to_s] = [type, opts]
        return unless Helpers.seen_names_add?(graphql_query, :arguments, name)

        graphql_query.class_eval { argument(name, type, **opts) }
      end

      def graphql_connection_query_argument_now(name, type, **opts)
        graphiform_connection_query_specs[:arguments][name.to_s] = [type, opts]
        return unless Helpers.seen_names_add?(graphql_connection_query, :arguments, name)

        graphql_connection_query.class_eval { argument(name, type, **opts) }
      end

      def graphql_grouping_argument_now(name, type, **opts)
        return unless Helpers.seen_names_add?(graphql_grouping, :arguments, name)

        graphql_grouping.class_eval { argument(name, type, **opts) }
      end

      def graphql_input_argument_now(name, type, **opts)
        return unless Helpers.seen_names_add?(graphql_input, :arguments, name)

        graphql_input.class_eval { argument(name, type, **opts) }
      end

      def graphql_readable_field_now(
        name,
        as: nil,
        read_prepare: nil,
        null: nil,
        **options
      )
        identifier = as || name
        reflection = reflect_on_association(name)

        # Explicit type provided for a polymorphic association: trust the caller,
        # treat it as a method-style field. Skip Scopiform's association(identifier)
        # because reflection.klass crashes on polymorphic reflections.
        if reflection&.polymorphic? && options[:type].present?
          graphql_add_method_field(name, read_prepare: read_prepare, null: null, as: as, **options)
          # Polymorphic associations cannot participate in filter/sort/grouping
          # statically — skip those rather than crash.
          return
        end

        # Polymorphic without explicit type: cannot auto-expose. Warn and skip.
        if reflection&.polymorphic?
          raise ArgumentError(
            "[Graphiform] Skipping polymorphic association `#{identifier}` on #{self.name}: " \
            'pass an explicit `type:` (typically a union) to expose it.'
          )
        end
        column_def = column(identifier)
        association_def = association(identifier)

        graphql_add_column_field(name, column_def, read_prepare: read_prepare, null: null, as: as, **options) if column_def.present?
        graphql_add_association_field(name, association_def, read_prepare: read_prepare, null: null, as: as, **options) if association_def.present?
        graphql_add_method_field(name, read_prepare: read_prepare, null: null, as: as, **options) unless column_def.present? || association_def.present?

        graphql_add_scopes_to_filter(name, identifier, **options)
        graphql_field_to_sort(name, identifier, **options)
        graphql_field_to_grouping(name, identifier, **options)
      end

      def graphql_writable_field_now(
        name,
        type: nil,
        required: false,
        write_prepare: nil,
        prepare: nil,
        description: nil,
        as: nil,
        **args
      )
        name = name.to_sym
        has_nested_attributes_method = instance_methods.include?("#{as || name}_attributes=".to_sym)
        argument_name = has_nested_attributes_method ? "#{name}_attributes".to_sym : name
        argument_type = graphql_resolve_argument_type(as || name, type)
        as = has_nested_attributes_method ? "#{as}_attributes".to_sym : as.to_sym if as

        return Helpers.logger.warn "Graphiform: Missing `type` for argument `#{name}` in model `#{self.name}`" if argument_type.nil?

        prepare = write_prepare || prepare

        return unless Helpers.seen_names_add?(graphql_input, :arguments, argument_name)

        graphql_input.class_eval do
          argument(
            argument_name,
            argument_type,
            required: required,
            prepare: prepare,
            description: description,
            as: as,
            **args
          )
        end
      end

      def graphql_field_now(
        name,
        write_name: nil,
        readable: true,
        writable: false,
        read_prepare: nil,
        write_prepare: nil,
        null: nil,
        **options
      )
        graphql_readable_field_now(name, read_prepare: read_prepare, null: null, **options) if readable
        graphql_writable_field_now(write_name || name, write_prepare: write_prepare, **options) if writable
      end

      def graphql_fields_now(*names, **options)
        names.each do |name|
          graphql_field_now(name, **options)
        end
      end

      def graphql_readable_fields_now(*names, **options)
        names.each do |name|
          graphql_readable_field_now(name, **options)
        end
      end

      def graphql_writable_fields_now(*names, **options)
        names.each do |name|
          graphql_writable_field_now(name, **options)
        end
      end

      private

      def graphql_resolve_argument_type(name, type)
        type = graphql_create_enum(name) if type.blank? && enum_attribute?(name)
        return Helpers.graphql_type(type) if type.present?

        column_def = column(name)
        return Helpers.graphql_type(column_def.type) if column_def.present?

        association_def = association(name)
        return nil unless Helpers.association_arguments_valid?(association_def, :graphql_input)

        klass = association_def.klass
        has_many = association_def.macro == :has_many
        has_many ? -> { [klass.graphql_input] } : -> { klass.graphql_input }
      end

      def graphql_add_scopes_to_filter(name, as, **options)
        added_scopes = auto_scopes_by_attribute(as)
        return if added_scopes.empty?

        association_def = association(as)
        type = nil
        if association_def.present?
          return unless Helpers.association_arguments_valid?(association_def, :graphql_filter)
          klass = association_def.klass
          type = -> { klass.graphql_filter }
        end

        filter_only_by_scopes = added_scopes.select do |scope_def|
          !scope_def.options || scope_def.options[:type].blank? || scope_def.options[:type] == :enum
        end

        filter_only_by_scopes.each do |added_scope|
          scope_argument_type = type || added_scope.options[:argument_type]
          if added_scope.options[:type] == :enum
            enum = graphql_create_enum(name)
            scope_argument_type = scope_argument_type.is_a?(Array) ? [enum] : enum
          end
          add_scope_def_to_filter(name, added_scope, scope_argument_type, **options)
        end
      end

      def add_scope_def_to_filter(name, scope_def, argument_type, **options)
        return unless argument_type
        argument_type = Helpers.graphql_type(argument_type) unless argument_type.is_a?(Proc)
        argument_attribute = name
        argument_prefix = scope_def.prefix
        argument_suffix = scope_def.suffix == '_is' ? '' : scope_def.suffix
        argument_name = "#{argument_prefix}#{argument_attribute}#{argument_suffix}".underscore
        scope_name = scope_def.name

        return unless Helpers.seen_names_add?(graphql_filter, :arguments, argument_name)

        graphql_filter.class_eval do
          argument(
            argument_name,
            argument_type,
            required: false,
            as: scope_name,
            **options
          )
        end
      end

      def graphql_field_to_sort(name, as, **options)
        column_def = column(as || name)
        association_def = association(as || name)

        type = ::Graphiform::SortEnum if column_def.present?
        if Helpers.association_arguments_valid?(association_def, :graphql_sort)
          klass = association_def.klass
          type = -> { klass.graphql_sort }
        end
        return if type.blank?

        return unless Helpers.seen_names_add?(graphql_sort, :arguments, name)

        local_graphql_sort = graphql_sort
        local_graphql_sort.class_eval do
          argument(
            name,
            type,
            required: false,
            as: as,
            **options
          )
        end
      end

      def graphql_field_to_grouping(name, as, **options)
        column_def = column(as || name)
        association_def = association(as || name)

        type = GraphQL::Types::Boolean if column_def.present?
        if Helpers.association_arguments_valid?(association_def, :graphql_grouping)
          klass = association_def.klass
          type = -> { klass.graphql_grouping }
        end
        return if type.blank?

        return unless Helpers.seen_names_add?(graphql_grouping, :arguments, name)

        local_graphql_grouping = graphql_grouping
        local_graphql_grouping.class_eval do
          argument(
            name,
            type,
            required: false,
            as: as,
            **options
          )
        end
      end

      def graphql_add_field_to_type(
        field_name,
        type,
        null = nil,
        description: nil,
        deprecation_reason: nil,
        method: nil,
        as: nil,
        read_prepare: nil,
        read_resolve: nil,
        **options
      )
        type = Helpers.graphql_type(type) unless type.is_a?(Proc)
        is_resolver = !type.is_a?(Proc) && Helpers.resolver?(type)
        field_name = field_name.to_sym

        field_options = {
          description: description,
          deprecation_reason: deprecation_reason,
          method: is_resolver ? nil : method || as,
        }

        if is_resolver
          field_options[:resolver] = type
        else
          field_options[:type] = type
          field_options[:null] = null
        end

        return unless Helpers.seen_names_add?(graphql_type, :fields, field_name)

        graphql_type.class_eval do
          added_field = field(field_name, **field_options, **options)

          if read_prepare || read_resolve
            define_method(
              added_field.method_sym,
              lambda do
                value = read_resolve ? instance_exec(object, context, &read_resolve) : object.public_send(added_field.method_sym)
                value = instance_exec(value, context, &read_prepare) if read_prepare
                value
              end
            )
          end
        end
      end

      def graphql_add_column_field(field_name, column_def, type: nil, null: nil, as: nil, **options)
        is_enum = type.blank? && enum_attribute?(as || field_name)

        if is_enum
          enum = graphql_create_enum(as || field_name)
          type = enum
        end

        type ||= column_def.type
        null = column_def.null if null.nil?

        graphql_add_field_to_type(field_name, type, null, as: as, **options)
      end

      def graphql_add_association_field(
        field_name,
        association_def,
        type: nil,
        null: nil,
        include_connection: true,
        read_prepare: nil,
        read_resolve: nil,
        skip_dataloader: false,
        **options
      )
        klass = association_def.klass

        unless klass.respond_to?(:graphql_type)
          return Helpers.logger.warn(
            "Graphiform: `#{name}` trying to add association `#{field_name}` - " \
            "`#{klass.name}` does not include Graphiform"
          )
        end

        has_many = association_def.macro == :has_many

        if include_connection && has_many
          connection_type_thunk = lambda do
            t = klass.graphql_connection
            if klass.graphql_type.fields.empty?
              Helpers.logger.warn(
                "Graphiform: `#{name}` referenced association `#{field_name}` - " \
                "`#{klass.name}` has no fields defined"
              )
            end
            t
          end

          connection_resolver = klass.graphql_create_resolver(
            association_def.name,
            connection_type_thunk,
            read_prepare: read_prepare,
            read_resolve: read_resolve,
            null: false,
            skip_dataloader: true
          )

          graphql_add_field_to_type(
            "#{field_name}_connection",
            connection_resolver,
            false,
            **options
          )
        end

        if type.nil?
          type =
            if has_many
              list_type_thunk = lambda do
                t = klass.graphql_type
                if t.fields.empty?
                  Helpers.logger.warn(
                    "Graphiform: `#{name}` referenced association `#{field_name}` - " \
                    "`#{klass.name}` has no fields defined"
                  )
                end
                [t]
              end

              klass.graphql_create_resolver(
                association_def.name,
                list_type_thunk,
                read_prepare: read_prepare,
                read_resolve: read_resolve,
                null: false,
                skip_dataloader: skip_dataloader
              )
            else
              single_type_thunk = lambda do
                t = klass.graphql_type
                if t.fields.empty?
                  Helpers.logger.warn(
                    "Graphiform: `#{name}` referenced association `#{field_name}` - " \
                    "`#{klass.name}` has no fields defined"
                  )
                end
                t
              end

              klass.graphql_create_association_resolver(
                association_def,
                single_type_thunk,
                skip_dataloader: skip_dataloader
              )
            end

          if has_many
            read_prepare = nil
            read_resolve = nil
          end
        end

        null = association_def.macro != :has_many if null.nil?
        graphql_add_field_to_type(field_name, type, null, read_prepare: read_prepare, read_resolve: read_resolve, **options)
      end

      def graphql_add_method_field(field_name, type: nil, null: true, **options)
        return Helpers.logger.warn "Graphiform: Missing `type` for field `#{field_name}` in model `#{name}`" if type.nil?

        null = true if null.nil?

        type = graphql_create_method_resolver(field_name, type, null: null)

        graphql_add_field_to_type(field_name, type, null, **options)
      end
    end
  end
end
