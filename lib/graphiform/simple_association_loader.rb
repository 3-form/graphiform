# frozen_string_literal: true

require 'graphql/batch'

module Graphiform
  class SimpleAssociationLoader < GraphQL::Batch::Loader
    def initialize(model, attribute)
      super

      @model = model
      @attribute = attribute
    end

    def perform(values)
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

      query.each do |record|
        value = is_composite ? @attribute.map { |single_value| record[single_value] } : record[@attribute]
        fulfill(value, record)
      end
      values.each { |value| fulfill(value, nil) unless fulfilled?(value) }
    end
  end
end
