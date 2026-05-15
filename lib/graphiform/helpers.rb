# frozen_string_literal: true
require 'set'

module Graphiform
  module Helpers
    def self.canonical_graphql_name(name)
      name.to_s.camelize(:lower)
    end

    def self.seen_names(type, bucket)
      ivar = :"@_graphiform_seen_#{bucket}"
      cached = type.instance_variable_get(ivar)
      return cached if cached

      set = Set.new
      existing_keys =
        case bucket
        when :arguments then type.arguments.keys
        when :fields    then type.fields.keys
        else raise ArgumentError, "Unknown Graphiform seen_names bucket: #{bucket.inspect}"
        end
      existing_keys.each { |k| set.add(canonical_graphql_name(k)) }
      type.instance_variable_set(ivar, set)
      set
    end

    def self.seen_names_add?(type, bucket, name)
      seen_names(type, bucket).add?(canonical_graphql_name(name)) ? true : false
    end

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

      Graphiform.configuration[:scalar_mappings][active_record_type.to_sym] || active_record_type
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

    def self.equal_graphql_names?(key, name)
      key.downcase == name.to_s.camelize.downcase || key.downcase == name.to_s.downcase
    end

    def self.full_const_name(name)
      name = "Object#{name}" if name.starts_with?('::')
      name = "Object::#{name}" unless name.starts_with?('Object::')

      name
    end

    def self.association_arguments_valid?(association_def, _method_name)
      return false unless association_def
      return false if association_def.options && association_def.options[:polymorphic]

      klass = begin
        association_def.klass
      rescue StandardError
        nil
      end
      return false unless klass

      klass.include?(Graphiform)
    end

    def self.dataloader_support?(dataloader, association_def)
      association_def.present? &&
        !association_def.polymorphic? &&
        !association_def.inverse_of&.polymorphic? &&
        !dataloader.is_a?(GraphQL::Dataloader::NullDataloader)
    end
  end
end
