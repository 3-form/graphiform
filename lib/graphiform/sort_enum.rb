require 'graphql'

module Graphiform
  class SortEnum < ::GraphQL::Schema::Enum
    value 'ASC', 'Sort results in ascending order'
    value 'DESC', 'Sort results in descending order'
  end
end
