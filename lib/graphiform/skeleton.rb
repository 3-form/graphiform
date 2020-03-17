require 'graphql'
require 'graphiform/helpers'

module Graphiform
  def self.create_skeleton
    return if defined? @skeleton_created

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

    Helpers.get_const_or_create('Filters', ::Inputs) do
      Module.new
    end

    Helpers.get_const_or_create('BaseFilter', ::Inputs::Filters) do
      Class.new(::GraphQL::Schema::InputObject)
    end

    Helpers.get_const_or_create('Sorts', ::Inputs) do
      Module.new
    end

    Helpers.get_const_or_create('BaseSort', ::Inputs::Sorts) do
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
    Helpers.get_const_or_create('Queries', ::Resolvers) do
      Module.new
    end

    Helpers.get_const_or_create('BaseQuery', ::Resolvers::Queries) do
      Class.new(::GraphQL::Schema::Resolver)
    end

    # Connection Queries
    Helpers.get_const_or_create('ConnectionQueries', ::Resolvers) do
      Module.new
    end

    Helpers.get_const_or_create('BaseQuery', ::Resolvers::ConnectionQueries) do
      Class.new(::GraphQL::Schema::Resolver)
    end

    # Enums
    Helpers.get_const_or_create('Enums') do
      Module.new
    end

    Helpers.get_const_or_create('BaseEnum', ::Enums) do
      Class.new(::GraphQL::Schema::Enum)
    end

    Helpers.get_const_or_create('Sort', ::Enums) do
      Class.new(::Enums::BaseEnum) do
        value 'ASC', 'Sort results in ascending order'
        value 'DESC', 'Sort results in descending order'
      end
    end

    @skeleton_created = true
  end
end
