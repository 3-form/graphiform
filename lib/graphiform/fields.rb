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
        graphql_field_to_sorting(name)
      end

      def graphql_writable_field(
        name,
        type: nil,
        required: false,
        **_options
      )
        name = name.to_sym
        argument_name = graphql_resolve_argument_name(name)
        argument_type = graphql_resolve_argument_type(name, type)

        graphql_input.class_eval do
          argument argument_name, argument_type, required: required
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
        return type if type.present?

        column_def = column(name)

        return Helpers.graphql_type(column_def.type) if column_def.present?

        association_def = association(name)

        if association_def.present?
          has_many = association_def.macro == :has_many
          return has_many ? [association_def.klass.graphql_input] : association_def.klass.graphql_input
        end

        raise StandardError, 'Some sort of error' # TODO
      end

      def graphql_add_scopes_to_filter(name)
        added_scopes = auto_scopes_by_attribute(name)

        return if added_scopes.empty?

        association_def = association(name)

        type = association_def.klass.graphql_filter if association_def.present?

        added_scopes.each do |added_scope|
          add_scope_def_to_filter(added_scope, type || added_scope.options[:argument_type])
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

      def graphql_field_to_sorting(name)
        column_def = column(name)
        association_def = association(name)

        type = ::Enums::Order if column_def.present?
        if association_def.present? && association_def.klass.graphql_sorting_filter && !association_def.klass.graphql_sorting_filter.arguments.empty?
          type = association_def.klass.graphql_sorting_filter
        end

        return unless type.present?

        sorting = graphql_sorting_filter

        sorting.class_eval do
          argument(
            name,
            type,
            required: false
          )
        end
      end

      def graphql_add_field_to_type(field_name, type, null = nil)
        field_name = field_name.to_sym
        field_options = {}

        if resolver?(type)
          field_options[:resolver] = type
        else
          field_options[:type] = type
          field_options[:null] = null
        end

        graphql_type.class_eval do
          field(field_name, **field_options)
        end
      end

      def graphql_add_column_field(field_name, column_def, type: nil, null: nil, **_options)
        type = Helpers.graphql_type(type || column_def.type)
        null = column_def.null if null.nil?

        graphql_add_field_to_type(field_name, type, null)
      end

      def graphql_add_association_field(field_name, association_def, type: nil, null: nil, **_options)
        raise StandardError, "`#{name}` does not extend ActiveRecord::Graphql" unless association_def.klass.methods.include?(:graphql_type) # TODO: Specialize error

        has_many = association_def.macro == :has_many
        klass = association_def.klass

        if has_many
          graphql_add_field_to_type(
            "#{field_name}_connection",
            klass.graphql_create_resolver(association_def.name, graphql_connection),
            false
          )
        end

        type = has_many ? klass.graphql_create_resolver(association_def.name, [klass.graphql_type]) : klass.graphql_type if type.nil?
        null = association_def.macro != :has_many if null.nil?

        graphql_add_field_to_type(field_name, type, null)
      end

      def graphql_add_method_field(field_name, type:, null: true, **_options)
        graphql_add_field_to_type(field_name, type, null)
      end
    end
  end
end
