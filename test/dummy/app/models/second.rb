class Second < ApplicationRecord
  include Graphiform

  belongs_to :first
  has_many :thirds

  graphql_fields \
    :name,
    :datetime,
    :number,
    # config
    writable: true
end
