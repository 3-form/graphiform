# frozen_string_literal: true

module Graphiform
  class AssociationSource < GraphQL::Dataloader::Source
    def initialize(model, attribute, **options)
      super()

      @model = model
      @attribute = attribute
      @options = options
    end

    def fetch(values)
      normalized_values = normalize_values(values)
      records = query(normalized_values.uniq).to_a
      results(normalized_values, records)
    end

    def query(values)
      query = @model.where(@attribute => values)

      query = query.includes(@options[:includes]) if @options[:includes].present? && query.respond_to?(:includes)
      query = query.apply_filters(@options[:where].to_h) if @options[:where].present? && query.respond_to?(:apply_filters)
      query = query.apply_sorts(@options[:sort].to_h) if @options[:sort].present? && query.respond_to?(:apply_sorts)

      query
    end

    def normalize_value(value)
      value = value.downcase if !@options[:case_sensitive] && value.is_a?(String)

      value
    end

    def normalize_values(values)
      type_for_attribute = @model.type_for_attribute(@attribute) if @model.respond_to?(:type_for_attribute)
      values.map do |value|
        value = type_for_attribute.cast(value) if type_for_attribute.present?
        normalize_value(value)
      end
    end

    def results(values, records)
      record_attributes = records.map { |record| normalize_value(record[@attribute]) }
      values.map do |value|
        if @options[:multi]
          indexes = record_attributes.each_index.select { |index| record_attributes[index] == value }
          indexes.map { |index| index && records[index] }
        else
          index = record_attributes.index(value)
          index && records[index]
        end
      end
    end
  end
end
