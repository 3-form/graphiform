require 'graphql'
require 'graphiform/helpers'

module Graphiform
  # Types
  Helpers.get_const_or_create('Types') do
    Module.new
  end

  Helpers.get_const_or_create('BaseObject', ::Types) do
    Class.new(::GraphQL::Schema::Object)
  end

  Helpers.get_const_or_create('BaseEdge', ::Types) do
    Class.new(::GraphQL::Types::Relay::BaseEdge)
  end

  Helpers.get_const_or_create('BaseConnection', ::Types) do
    Class.new(::GraphQL::Types::Relay::BaseConnection)
  end

  # Inputs
  Helpers.get_const_or_create('Inputs') do
    Module.new
  end

  Helpers.get_const_or_create('BaseInput', ::Inputs) do
    Class.new(::GraphQL::Schema::InputObject)
  end

  # Resolvers
  Helpers.get_const_or_create('Resolvers') do
    Module.new
  end

  Helpers.get_const_or_create('BaseResolver', ::Resolvers) do
    Class.new(::GraphQL::Schema::Resolver)
  end

  # Queries
  Helpers.get_const_or_create('Queries') do
    Module.new
  end

  Helpers.get_const_or_create('BaseQuery', ::Queries) do
    Class.new(::GraphQL::Schema::Resolver)
  end
end

# Types
#   BaseObject
#   BaseEdge
#   BaseConnection
# Inputs
#   BaseInput
# Filters
#   BaseFilter
# Resolvers
#   BaseResolver
# ConnectionQueries

# Helpers.get_const_or_create('Types') do
#   Class.new(::Types::BaseObject) do
#     graphql_name demodulized_name
#   end
# end
