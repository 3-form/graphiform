class Third < ApplicationRecord
  include Graphiform

  belongs_to :second, optional: true

  enum :status, { active: 0, inactive: 1, discontinued: 2 }

  graphql_fields \
    :name,
    :status,
    # config
    writable: true

  graphql_fields \
    :id
end
