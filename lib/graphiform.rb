require 'scopiform'

require 'graphiform/skeleton'

require 'graphiform/active_record_helpers'
require 'graphiform/core'
require 'graphiform/fields'
require 'graphiform/sort_enum'

module Graphiform
  def self.included(base)
    Graphiform.create_skeleton

    base.class_eval do
      include Scopiform

      include Graphiform::ActiveRecordHelpers
      include Graphiform::Core
      include Graphiform::Fields
    end
  end

  def self.configuration
    @configuration ||= {
      scalar_mappings: {
        string: GraphQL::Types::String,
        text: GraphQL::Types::String,
        # nchar: GraphQL::Types::String,
        varchar: GraphQL::Types::String,

        date: GraphQL::Types::ISO8601Date,

        time: GraphQL::Types::ISO8601DateTime,
        datetime: GraphQL::Types::ISO8601DateTime,
        timestamp: GraphQL::Types::ISO8601DateTime,

        integer: GraphQL::Types::Int,

        float: GraphQL::Types::Float,
        decimal: GraphQL::Types::Float,

        boolean: GraphQL::Types::Boolean,

        json: GraphQL::Types::JSON,
        jsonb: GraphQL::Types::JSON,
      },
    }
  end

  def self.configure
    yield(configuration)
  end
end
