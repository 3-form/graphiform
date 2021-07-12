# frozen_string_literal: true

require 'graphql/batch'

GraphQL::Batch::Executor.class_eval do
  def clear
    puts "CLEARING HERE #{instance_variable_get(:@loaders).keys.count}"
    # if instance_variable_get(:@loaders).keys.count > 0
    #   raise 'an error'
    # end
  end
end

module Graphiform
  class AssociationLoader < GraphQL::Batch::Loader
    def initialize(model, attribute, where: nil, sort: nil)
      super()

      @model = model
      @attribute = attribute
      @where = where
      @sort = sort
      # @group = group
    end

    def load(key)
      puts "BATCH QUEUE #{key}"
      super(key.is_a?(String) ? key.downcase : key)
    end

    def self.for(model, *group_args)
      key_args = [model.name, *group_args]
      puts "FOR #{loader_key_for(*key_args)}"
      current_executor.loader(loader_key_for(*key_args)) {
        my_executor = send(:current_executor)
        puts "DOES NOT EXIST #{my_executor.object_id}"
        puts my_executor.instance_variable_get(:@loaders).keys.count
        new(model, *group_args)
      }
    end

    def perform(values)
      puts "QUERYING #{values} using Executor #{executor.object_id} on loader #{object_id}"
      query = @model
      is_composite = @attribute.is_a?(Array)

      if is_composite
        # Composite key
        or_queries = values.map do |value_set|
          conditions = Hash[@attribute.each_with_index.collect { |single_attribute, index| [single_attribute, value_set[index]] }]
          query.where(conditions)
        end

        query = or_queries.reduce { |combined, or_query| combined.or(or_query) }
      else
        query = query.where(@attribute => values)
      end

      query = query.apply_filters(@where.to_h) if @where.present? && query.respond_to?(:apply_filters)
      query = query.apply_sorts(@sort.to_h) if @sort.present? && query.respond_to?(:apply_sorts)
      # Grouping not supporting.  Might be able to support if grouped by attribute first...
      # query = query.apply_groupings(@group.to_h) if @group.present? && query.respond_to?(:apply_groupings)

      query.each do |record|
        value = is_composite ? @attribute.map { |single_value| record[single_value] } : record[@attribute]
        fulfill(value.is_a?(String) ? value.downcase : value, record)
      end
      values.each { |value| fulfill(value, nil) unless fulfilled?(value) }
    end
  end
end
