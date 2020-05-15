class First < ApplicationRecord
  include Graphiform

  has_many :seconds
  has_many :has_no_fields
  has_many :has_no_includes

  accepts_nested_attributes_for :seconds

  graphql_fields \
    :name,
    :date,
    :number,
    :boolean,
    # association
    :seconds,
    # config
    writable: true

  graphql_fields \
    :id,
    :updated_at,
    :created_at,
    # associations
    :has_no_fields,
    :has_no_includes

  graphql_field :alias_id, as: :id, writable: true
  graphql_field :alias_seconds, as: :seconds, writable: true
  graphql_field :alias_basic_method, type: :string, as: :basic_method, writable: true

  def basic_method
    'response'
  end
end
