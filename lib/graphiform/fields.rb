# frozen_string_literal: true

require 'active_support/concern'

module Graphiform
  module Fields
    extend ActiveSupport::Concern

    module ClassMethods
      def graphql_readable_field(
        name,
        as: nil,
        **options
      )
        identifier = as || name
        column_def = column(identifier)
        association_def = association(identifier)

        graphql_add_column_field(name, column_def, as: as, **options) if column_def.present?
        graphql_add_association_field(name, association_def, as: as, **options) if association_def.present?
        graphql_add_method_field(name, as: as, **options) unless column_def.present? || association_def.present?

        graphql_add_scopes_to_filter(name, identifier)
        graphql_field_to_sort(name, identifier)
        graphql_field_to_grouping(name, identifier)
      end

      def graphql_writable_field(
        name,
        type: nil,
        required: false,
        write_prepare: nil,
        prepare: nil,
        description: nil,
        default_value: ::GraphQL::Schema::Argument::NO_DEFAULT,
        as: nil,
        **
      )
        name = name.to_sym
        has_nested_attributes_method = instance_methods.include?("#{as || name}_attributes=".to_sym)

        argument_name = has_nested_attributes_method ? "#{name}_attributes".to_sym : name
        argument_type = graphql_resolve_argument_type(as || name, type)
        as = has_nested_attributes_method ? "#{as}_attributes".to_sym : as.to_sym if as

        return Helpers.logger.warn "Graphiform: Missing `type` for argument `#{name}` in model `#{self.name}`" if argument_type.nil?

        prepare = write_prepare || prepare

        graphql_input.class_eval do
          argument(
            argument_name,
            argument_type,
            required: required,
            prepare: prepare,
            description: description,
            default_value: default_value,
            as: as,
            method_access: false
          )
        end
      end

      def graphql_field(
        name,
        write_name: nil,
        readable: true,
        writable: false,
        **options
      )
        graphql_readable_field(name, **options) if readable
        graphql_writable_field(write_name || name, **options) if writable
      end

      def graphql_fields(*names, **options)
        names.each do |name|
          graphql_field(name, **options)
        end
      end

      def graphql_readable_fields(*names, **options)
        names.each do |name|
          graphql_readable_field(name, **options)
        end
      end

      def graphql_writable_fields(*names, **options)
        names.each do |name|
          graphql_writable_field(name, **options)
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

        has_many = association_def.macro == :has_many
        has_many ? [association_def.klass.graphql_input] : association_def.klass.graphql_input
      end

      def graphql_add_scopes_to_filter(name, as)
        added_scopes = auto_scopes_by_attribute(as)

        return if added_scopes.empty?

        association_def = association(as)

        if association_def.present?
          return unless Helpers.association_arguments_valid?(association_def, :graphql_filter)

          type = association_def.klass.graphql_filter
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
          add_scope_def_to_filter(name, added_scope, scope_argument_type)
        end
      end

      def add_scope_def_to_filter(name, scope_def, argument_type)
        return unless argument_type

        argument_type = Helpers.graphql_type(argument_type)
        argument_attribute = name
        argument_prefix = scope_def.prefix
        argument_suffix = scope_def.suffix == '_is' ? '' : scope_def.suffix
        argument_name = "#{argument_prefix}#{argument_attribute}#{argument_suffix}".underscore
        scope_name = scope_def.name

        graphql_filter.class_eval do
          argument(
            argument_name,
            argument_type,
            required: false,
            as: scope_name,
            method_access: false
          )
        end
      end

      def graphql_field_to_sort(name, as)
        column_def = column(as || name)
        association_def = association(as || name)

        type = ::Graphiform::SortEnum if column_def.present?
        type = association_def.klass.graphql_sort if Helpers.association_arguments_valid?(association_def, :graphql_sort)

        return if type.blank?

        local_graphql_sort = graphql_sort

        local_graphql_sort.class_eval do
          argument(
            name,
            type,
            required: false,
            as: as,
            method_access: false
          )
        end
      end

      def graphql_field_to_grouping(name, as)
        column_def = column(as || name)
        association_def = association(as || name)

        type = GraphQL::Types::Boolean if column_def.present?
        type = association_def.klass.graphql_grouping if Helpers.association_arguments_valid?(association_def, :graphql_grouping)

        return if type.blank?

        local_graphql_grouping = graphql_grouping

        local_graphql_grouping.class_eval do
          argument(
            name,
            type,
            required: false,
            as: as,
            method_access: false
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
        **
      )
        type = Helpers.graphql_type(type)
        is_resolver = Helpers.resolver?(type)

        field_name = field_name.to_sym
        field_options = {
          description: description,
          deprecation_reason: deprecation_reason,
          method: is_resolver ? nil : method || as,
        }

        if Helpers.resolver?(type)
          field_options[:resolver] = type
        else
          field_options[:type] = type
          field_options[:null] = null
        end

        graphql_type.class_eval do
          added_field = field(field_name, **field_options)

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
        case_sensitive: Graphiform.configuration[:case_sensitive],
        **options
      )
        unless association_def.klass.respond_to?(:graphql_type)
          return Helpers.logger.warn(
            "Graphiform: `#{name}` trying to add association `#{field_name}` - `#{association_def.klass.name}` does not include Graphiform"
          )
        end

        if association_def.klass.graphql_type.fields.empty?
          return Helpers.logger.warn(
            "Graphiform: `#{name}` trying to add association `#{field_name}` - `#{association_def.klass.name}` has no fields defined"
          )
        end

        has_many = association_def.macro == :has_many
        klass = association_def.klass

        if include_connection && has_many
          graphql_add_field_to_type(
            "#{field_name}_connection",
            klass.graphql_create_resolver(
              association_def.name,
              klass.graphql_connection,
              read_prepare: read_prepare,
              read_resolve: read_resolve,
              null: false,
              skip_dataloader: true,
              case_sensitive: case_sensitive
            ),
            false,
            **options
          )
        end

        if type.nil?
          type = (
            if has_many
              klass.graphql_create_resolver(
                association_def.name,
                [klass.graphql_type],
                read_prepare: read_prepare,
                read_resolve: read_resolve,
                null: false,
                skip_dataloader: skip_dataloader,
                case_sensitive: case_sensitive
              )
            else
              klass.graphql_create_association_resolver(
                association_def,
                klass.graphql_type,
                skip_dataloader: skip_dataloader,
                case_sensitive: case_sensitive
              )
            end
          )

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

        graphql_add_field_to_type(field_name, type, null, **options)
      end
    end
  end
end
