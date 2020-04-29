class Third < ApplicationRecord
  include Graphiform

  belongs_to :second

  enum status: { inactive: 0, active: 1, discontinued: 2 }

  graphql_fields \
    :name,
    :status,
    # config
    writable: true

  graphql_fields \
    :id
end
