require 'test_helper'

class GraphqlQueryTest < ActiveSupport::TestCase
  setup do
    @first_a = First.create(name: 'abc', date: '2010-10-05', number: 5, boolean: true)
    @first_b = First.create(name: 'def', date: '2020-05-10', number: 10, boolean: false)
    @first_c = First.create(name: 'ghi', date: '2020-04-10', number: 20, boolean: true)

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :first, resolver: First.graphql_query
    end
    @schema = Class.new(GraphQL::Schema) do
      query(query)
    end
  end

  test 'has graphql_query available' do
    assert_respond_to First, :graphql_query
    assert_not_empty First.graphql_query.arguments

    assert_equal First.graphql_type, First.graphql_query.type.of_type

    assert First.graphql_query.arguments['where']
    assert_equal First.graphql_filter, First.graphql_query.arguments['where'].type
    assert First.graphql_query.arguments['sort']
    assert_equal First.graphql_sort, First.graphql_query.arguments['sort'].type
  end

  test 'basic query by id' do
    query = <<-GRAPHQL
      query($id: Int) {
        first(where: { id: $id }) {
          id
          name
          date
          number
          boolean
        }
      }
    GRAPHQL
    variables = {
      id: @first_b.id,
    }

    resp = @schema.execute(query, variables: variables)

    assert_equal @first_b.id, resp['data']['first']['id']
    assert_equal @first_b.name, resp['data']['first']['name']
    assert_equal @first_b.date.iso8601, resp['data']['first']['date']
    assert_equal @first_b.number, resp['data']['first']['number']
    assert_equal @first_b.boolean, resp['data']['first']['boolean']
  end

  test 'no results query' do
    query = <<-GRAPHQL
      query($name: String) {
        first(where: { name: $name }) {
          id
        }
      }
    GRAPHQL
    variables = {
      name: 'does not exist',
    }

    resp = @schema.execute(query, variables: variables)

    assert_nil resp['data']
  end

  test 'name starts with query' do
    query = <<-GRAPHQL
      query($name_starts_with: String) {
        first(where: { name_starts_with: $name_starts_with }) {
          id
        }
      }
    GRAPHQL
    variables = {
      name_starts_with: 'gh',
    }

    resp = @schema.execute(query, variables: variables)

    assert_equal @first_c.id, resp['data']['first']['id']
  end

  test 'empty where returns first' do
    query = <<-GRAPHQL
      query {
        first {
          id
        }
      }
    GRAPHQL
    variables = {}

    resp = @schema.execute(query, variables: variables)

    assert_equal First.first.id, resp['data']['first']['id']
  end
end
