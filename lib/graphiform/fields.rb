# frozen_string_literal: true

require 'active_support/concern'

module Graphiform
  module Fields
    extend ActiveSupport::Concern

    module ClassMethods
      def graphql_readable_field(
        name,
        **options
      )
        column_def = column(name)
        association_def = association(name)

        graphql_add_column_field(name, column_def, **options) if column_def.present?
        graphql_add_association_field(name, association_def, **options) if association_def.present?
        graphql_add_method_field(name, **options) unless column_def.present? || association_def.present?

        graphql_add_scopes_to_filter(name)
        graphql_field_to_sort(name)
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
        **_options
      )
        name = name.to_sym
        argument_name = graphql_resolve_argument_name(name)
        argument_type = graphql_resolve_argument_type(name, type)

        return Helpers.logger.warn "Graphiform: Missing `type` for argument #{name}" if argument_type.nil?

        prepare = write_prepare || prepare

        graphql_input.class_eval do
          argument \
            argument_name,
            argument_type,
            required: required,
            prepare: prepare,
            description: description,
            default_value: default_value,
            as: as
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

      def graphql_resolve_argument_name(name)
        attributes_name = "#{name}_attributes"

        return attributes_name.to_sym if instance_methods.include?("#{attributes_name}=".to_sym)

        name
      end

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

      def graphql_add_scopes_to_filter(name)
        added_scopes = auto_scopes_by_attribute(name)

        return if added_scopes.empty?

        association_def = association(name)

        if association_def.present?
          return unless Helpers.association_arguments_valid?(association_def, :graphql_filter)

          type = association_def.klass.graphql_filter
        end

        non_sort_by_scopes = added_scopes.select { |scope_def| !scope_def.options || scope_def.options[:type] != :sort }

        non_sort_by_scopes.each do |added_scope|
          scope_argument_type = type || added_scope.options[:argument_type]
          if added_scope.options[:type] == :enum
            enum = graphql_create_enum(name)
            scope_argument_type = scope_argument_type.is_a?(Array) ? [enum] : enum
          end
          add_scope_def_to_filter(added_scope, scope_argument_type)
        end
      end

      def add_scope_def_to_filter(scope_def, argument_type)
        return unless argument_type

        argument_type = Helpers.graphql_type(argument_type)
        camelized_attribute = scope_def.attribute.to_s.camelize(:lower)
        argument_prefix = scope_def.prefix
        argument_suffix = scope_def.suffix
        argument_suffix = argument_suffix == '_is' ? '' : argument_suffix
        argument_name = "#{argument_prefix}#{camelized_attribute}#{argument_suffix}"
        scope_name = scope_def.name

        graphql_filter.class_eval do
          argument(
            argument_name,
            argument_type,
            required: false,
            camelize: false,
            as: scope_name
          )
        end
      end

      def graphql_field_to_sort(name)
        column_def = column(name)
        association_def = association(name)

        type = ::Enums::Sort if column_def.present?
        type = association_def.klass.graphql_sort if Helpers.association_arguments_valid?(association_def, :graphql_sort)

        return if type.blank?

        local_graphql_sort = graphql_sort

        local_graphql_sort.class_eval do
          argument(
            name,
            type,
            required: false
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
        read_prepare: nil,
        **_options
      )
        field_name = field_name.to_sym
        field_options = {
          description: description,
          deprecation_reason: deprecation_reason,
          method: method,
        }

        type = Helpers.graphql_type(type)

        if Helpers.resolver?(type)
          field_options[:resolver] = type
        else
          field_options[:type] = type
          field_options[:null] = null
        end

        graphql_type.class_eval do
          added_field = field(field_name, **field_options)

          if read_prepare
            define_method(
              added_field.method_sym,
              -> { instance_exec(object.public_send(added_field.method_sym), context, &read_prepare) }
            )
          end
        end
      end

      def graphql_add_column_field(field_name, column_def, type: nil, null: nil, **options)
        is_enum = type.blank? && enum_attribute?(field_name)
        if is_enum
          enum = graphql_create_enum(field_name)
          type = enum
        end
        type ||= column_def.type
        null = column_def.null if null.nil?

        graphql_add_field_to_type(field_name, type, null, **options)
      end

      def graphql_add_association_field(field_name, association_def, type: nil, null: nil, include_connection: true, read_prepare: nil, **options)
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
            klass.graphql_create_resolver(association_def.name, klass.graphql_connection, read_prepare: read_prepare),
            false,
            **options
          )
        end

        if type.nil?
          type = has_many ? klass.graphql_create_resolver(association_def.name, [klass.graphql_type], read_prepare: read_prepare) : klass.graphql_type
          read_prepare = nil if has_many
        end

        null = association_def.macro != :has_many if null.nil?

        graphql_add_field_to_type(field_name, type, null, read_prepare: read_prepare, **options)
      end

      def graphql_add_method_field(field_name, type:, null: true, **options)
        return Helpers.logger.warn "Graphiform: Missing `type` for field `#{field_name}` in model `#{name}`" if type.nil?

        graphql_add_field_to_type(field_name, type, null, **options)
      end
    end
  end
end
