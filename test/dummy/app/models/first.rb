class First < ApplicationRecord
  include Graphiform

  has_many :seconds
  has_many :has_no_fields
  has_many :has_no_includes

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
end
