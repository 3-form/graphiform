# frozen_string_literal: true

module Graphiform
  module Helpers
    def self.graphql_type(active_record_type)
      is_array = active_record_type.is_a? Array
      active_record_type = is_array ? active_record_type[0] : active_record_type
      graphql_type = graphiform(active_record_type)
      is_array ? [graphql_type] : graphql_type
    end

    def self.graphql_type_single(active_record_type)
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
      else
        active_record_type
      end
    end

    def self.resolver?(val)
      val&.ancestors&.include?(GraphQL::Schema::Resolver)
    end

    def self.get_const_or_create(const, mod = Object)
      full_const_name = "#{mod}::#{const}"
      full_const_name.constantize
      Object.const_get(full_const_name)
    rescue NameError
      val = yield
      mod.const_set(const, val)
      val
    end

    module ClassMethods
    end
  end
end
