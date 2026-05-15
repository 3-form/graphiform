# frozen_string_literal: true

require 'set'

module Graphiform
  module Helpers
    def self.logger
      return Rails.logger if Rails.logger.present?

      @logger ||= Logger.new($stdout)
      @logger
    end

    # --- Name normalization & per-class registries -------------------------
    #
    # Replaces the O(n) `arguments.keys.any? { equal_graphql_names?(...) }`
    # scan (and its repeated string allocations) with an O(1) Set lookup.

    NAME_NORMALIZE_CACHE = {}
    NAME_NORMALIZE_MUTEX = Mutex.new

    # Canonicalize a name the same way graphql-ruby presents it externally,
    # so `:my_field`, `"my_field"`, `"myField"`, `"MyField"` all collide.
    def self.normalize_graphql_name(name)
      key = name.is_a?(Symbol) ? name : name.to_s
      cached = NAME_NORMALIZE_CACHE[key]
      return cached if cached

      NAME_NORMALIZE_MUTEX.synchronize do
        NAME_NORMALIZE_CACHE[key] ||= key.to_s.camelize(:lower).freeze
      end
    end

    # Fetch (and lazily seed) the registered-names Set for a generated
    # GraphQL class. Seeding from existing `arguments` / `fields` makes this
    # safe even when classes are pre-populated (e.g. `OR`/`AND` on filters,
    # or manual user-defined args).
    def self.tracked_names(klass)
      set = klass.instance_variable_get(:@graphiform_names)
      return set if set

      set = Set.new
      set.merge(klass.arguments.each_key.map { |k| normalize_graphql_name(k) }) if klass.respond_to?(:arguments)
      set.merge(klass.fields.each_key.map     { |k| normalize_graphql_name(k) }) if klass.respond_to?(:fields)
      klass.instance_variable_set(:@graphiform_names, set)
    end

    # Guard helper: yield (which should add the field/argument) only if the
    # name isn't already present. Returns true when the block ran.
    def self.add_unless_exists(klass, name)
      normalized = normalize_graphql_name(name)
      set = tracked_names(klass)
      return false if set.include?(normalized)

      yield
      set << normalized
      true
    end
    # -----------------------------------------------------------------------

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
      return mod.const_get(const) if mod.const_defined?(const, false)
      
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

    def self.dataloader_support?(dataloader, association_def)
      association_def.present? &&
        !association_def.polymorphic? &&
        !association_def.inverse_of&.polymorphic? &&
        !dataloader.is_a?(GraphQL::Dataloader::NullDataloader)
    end
  end
end