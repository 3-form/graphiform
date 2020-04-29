require 'test_helper'

class GraphqlConnectionQueryTest < ActiveSupport::TestCase
  setup do
    @first_a = First.create(name: 'abc', date: '2010-10-05', number: 5, boolean: true)
    @first_b = First.create(name: 'ghi', date: '2020-04-10', number: 20, boolean: true)
    @first_c = First.create(name: 'def', date: '2020-05-10', number: 10, boolean: false)

    @second_a = Second.create(first: @first_a, name: 'jayce', number: 10.82, datetime: '2020-03-16 21:17:20')
    @second_b = Second.create(first: @first_b, name: 'bailey', number: 8, datetime: '2020-03-16 1:17:20')
    @second_c = Second.create(first: @first_c, name: 'shane', number: 9.5, datetime: '2020-03-16 10:17:20')

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :firstConnection, resolver: First.graphql_connection_query
    end
    @schema = Class.new(GraphQL::Schema) do
      query(query)
    end
  end

  test 'has graphql_connection_query available' do
    assert_respond_to First, :graphql_connection_query
    assert_not_empty First.graphql_connection_query.arguments

    assert_equal First.graphql_connection, First.graphql_connection_query.type.of_type
    assert_kind_of GraphQL::Schema::NonNull, First.graphql_connection_query.type

    assert First.graphql_connection_query.arguments['where']
    assert_equal First.graphql_filter, First.graphql_connection_query.arguments['where'].type
    assert First.graphql_connection_query.arguments['sort']
    assert_equal First.graphql_sort, First.graphql_connection_query.arguments['sort'].type
  end

  test 'basic connection query by id' do
    query = <<-GRAPHQL
      query($id: Int) {
        firstConnection(where: { id: $id }) {
          pageInfo {
            hasNextPage
          }
          edges {
            node {
              id
              name
              date
              number
              boolean
            }
          }
        }
      }
    GRAPHQL
    variables = {
      id: @first_b.id,
    }

    resp = @schema.execute(query, variables: variables)
    edges = resp['data']['firstConnection']['edges']

    assert_not resp['data']['firstConnection']['pageInfo']['hasNextPage']
    assert_equal 1, edges.length

    node = edges.first['node']

    assert_equal @first_b.id, node['id']
    assert_equal @first_b.name, node['name']
    assert_equal @first_b.date.iso8601, node['date']
    assert_equal @first_b.number, node['number']
    assert_equal @first_b.boolean, node['boolean']
  end

  test 'no results connection query' do
    query = <<-GRAPHQL
      query($name: String) {
        firstConnection(where: { name: $name }) {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      name: 'does not exist',
    }

    resp = @schema.execute(query, variables: variables)

    assert_empty resp['data']['firstConnection']['nodes']
  end

  test 'empty where returns all' do
    query = <<-GRAPHQL
      query {
        firstConnection {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {}

    resp = @schema.execute(query, variables: variables)

    nodes = resp['data']['firstConnection']['nodes']

    assert_equal 3, nodes.length
    assert_equal @first_a.id, nodes[0]['id']
    assert_equal @first_b.id, nodes[1]['id']
    assert_equal @first_c.id, nodes[2]['id']
  end

  test 'sorting by name' do
    query = <<-GRAPHQL
      query($sort: FirstSort!) {
        firstConnection(sort: $sort) {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      sort: {
        name: 'DESC',
      },
    }

    resp = @schema.execute(query, variables: variables)

    nodes = resp['data']['firstConnection']['nodes']

    assert_equal @first_b.id, nodes[0]['id']
    assert_equal @first_c.id, nodes[1]['id']
    assert_equal @first_a.id, nodes[2]['id']
  end

  test 'filter by nested association' do
    query = <<-GRAPHQL
      query($where: FirstFilter!) {
        firstConnection(where: $where) {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      where: {
        seconds: {
          name: 'shane',
        },
      },
    }

    resp = @schema.execute(query, variables: variables)

    nodes = resp['data']['firstConnection']['nodes']

    assert_equal 1, nodes.length
    assert_equal @first_c.id, nodes[0]['id']
  end

  test 'sort by nested association' do
    query = <<-GRAPHQL
      query($sort: FirstSort!) {
        firstConnection(sort: $sort) {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      sort: {
        seconds: {
          name: 'ASC',
        },
      },
    }

    resp = @schema.execute(query, variables: variables)

    nodes = resp['data']['firstConnection']['nodes']

    assert_equal @first_b.id, nodes[0]['id']
    assert_equal @first_a.id, nodes[1]['id']
    assert_equal @first_c.id, nodes[2]['id']
  end
end
