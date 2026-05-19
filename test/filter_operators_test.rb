# test/filter_operators_test.rb
require 'test_helper'

class FilterOperatorsTest < ActiveSupport::TestCase
  setup do
    @a = First.create!(name: 'apple',  number: 1, boolean: true)
    @b = First.create!(name: 'banana', number: 5, boolean: false)
    @c = First.create!(name: 'cherry', number: 10, boolean: true)

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :firstConnection, resolver: First.graphql_connection_query
    end
    @schema = Class.new(GraphQL::Schema) do
      query(query)
    end
  end

  def ids_for(where)
    query = 'query($w: FirstFilter) { firstConnection(where: $w) { nodes { id } } }'
    results = @schema.execute(query, variables: { w: where })

    results['data']['firstConnection']['nodes'].map { |n| n['id'] }
  end

  test('numberGt filters greater than') { assert_equal [@c.id], ids_for(numberGt: 5) }
  test('numberLt filters less than')    { assert_equal [@a.id], ids_for(numberLt: 5) }
  test('numberGte includes boundary')   { assert_equal [@b.id, @c.id].sort, ids_for(numberGte: 5).sort }
  test('nameLike pattern matches')      { assert_equal [@a.id], ids_for(nameContains: 'app') }
  test('nameIn matches list')           { assert_equal [@a.id, @c.id].sort, ids_for(nameIn: %w[apple cherry]).sort }
  test('booleanEq matches false')       { assert_equal [@b.id], ids_for(boolean: false) }
  test('OR composes two clauses')       { assert_equal [@a.id, @c.id].sort, ids_for(OR: [{ name: 'apple' }, { name: 'cherry' }]).sort }
  test('AND composes two clauses')      { assert_equal [@c.id], ids_for(AND: [{ numberGte: 5 }, { boolean: true }]) }
end
