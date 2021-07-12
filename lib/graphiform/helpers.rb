# frozen_string_literal: true

module Graphiform
  module Helpers
    def self.logger
      return Rails.logger if Rails.logger.present?

      @logger ||= Logger.new($stdout)
      @logger
    end

    def self.graphql_type(active_record_type)
      is_array = active_record_type.is_a? Array
      active_record_type = is_array ? active_record_type[0] : active_record_type
      graphql_type = graphql_type_single(active_record_type)
      is_array ? [graphql_type] : graphql_type
    end

    def self.graphql_type_single(active_record_type)
      return active_record_type unless active_record_type.respond_to?(:to_sym)

      case active_record_type.to_sym
      when :string, :text
        GraphQL::Types::String
      when :date
        GraphQL::Types::ISO8601Date
      when :time, :datetime, :timestamp
        GraphQL::Types::ISO8601DateTime
      when :integer
        GraphQL::Types::Int
      when :float, :decimal
        GraphQL::Types::Float
      when :boolean
        GraphQL::Types::Boolean
      when :json, :jsonb
        GraphQL::Types::JSON
      else
        active_record_type
      end
    end

    def self.resolver?(val)
      val.respond_to?(:ancestors) &&
        val.ancestors.include?(GraphQL::Schema::Resolver)
    end

    def self.get_const_or_create(const, mod = Object)
      new_full_const_name = full_const_name("#{mod}::#{const}")
      new_full_const_name.constantize
      Object.const_get(new_full_const_name)
    rescue NameError => e
      unless full_const_name(e.missing_name) == new_full_const_name.to_s
        logger.warn "Failed to load #{e.missing_name} when loading constant #{new_full_const_name}"
        return Object.const_get(new_full_const_name)
      end

      val = yield
      mod.const_set(const, val)
      val
    end

    def self.full_const_name(name)
      name = "Object#{name}" if name.starts_with?('::')
      name = "Object::#{name}" unless name.starts_with?('Object::')

      name
    end

    def self.association_arguments_valid?(association_def, method)
      association_def.present? &&
        association_def.klass.respond_to?(method) &&
        association_def.klass.send(method).respond_to?(:arguments) &&
        !association_def.klass.send(method).arguments.empty?
    end
  end
end
