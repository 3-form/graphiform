require 'test_helper'

class GraphqlConnectionQueryAddonResolverTest < ActiveSupport::TestCase
  setup do
    @first_a = First.create(name: 'abc', date: '2010-10-05', number: 5, boolean: true)
    @first_b = First.create(name: 'ghi', date: '2020-04-10', number: 20, boolean: true)
    @first_c = First.create(name: 'def', date: '2020-05-10', number: 10, boolean: false)

    @second_a = Second.create(first: @first_a, name: 'jayce', number: 10.82, datetime: '2020-03-16 21:17:20')
    @second_b = Second.create(first: @first_b, name: 'bailey', number: 8, datetime: '2020-03-16 1:17:20')
    @second_c = Second.create(first: @first_c, name: 'shane', number: 9.5, datetime: '2020-03-16 10:17:20')

    First.graphql_connection_query.class_eval do
      def addon_resolve(**)
        value.where.not(name: 'ghi')
      end
    end

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :firstConnection, resolver: First.graphql_connection_query
    end
    @schema = Class.new(GraphQL::Schema) do
      query(query)
    end
  end

  teardown do
    First.graphql_connection_query.class_eval do
      remove_method :addon_resolve
    end
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
    assert_equal 0, edges.length
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

  test 'empty where returns all except addon-excluded' do
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

    assert_equal 2, nodes.length
    assert_equal @first_a.id, nodes[0]['id']
    assert_equal @first_c.id, nodes[1]['id']
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

    assert_equal @first_c.id, nodes[0]['id']
    assert_equal @first_a.id, nodes[1]['id']
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

    assert_equal @first_a.id, nodes[0]['id']
    assert_equal @first_c.id, nodes[1]['id']
  end
end
