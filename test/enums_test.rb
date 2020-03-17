require 'test_helper'

class EnumsTest < ActiveSupport::TestCase
  setup do
    @third_a = Third.create(name: 'abc', status: :discontinued)
    @third_b = Third.create(name: 'def', status: :active)
    @third_c = Third.create(name: 'ghi', status: :inactive)

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :thirdConnection, resolver: Third.graphql_connection_query
    end
    @schema = Class.new(GraphQL::Schema) do
      query(query)
    end
  end

  test 'enum type is :string' do
    query = <<-GRAPHQL
      query($id: Int) {
        thirdConnection(where: { id: $id }) {
          nodes {
            id
            name
            status
          }
        }
      }
    GRAPHQL
    variables = {
      id: @third_a.id,
    }

    resp = @schema.execute(query, variables: variables)
    nodes = resp['data']['thirdConnection']['nodes']

    assert_equal 1, nodes.length

    node = nodes.first

    assert_equal @third_a.id, node['id']
    assert_equal @third_a.name, node['name']
    assert_equal @third_a.status, node['status']

    assert_kind_of String, node['status']
  end

  # This is known to not work in rails 4
  # enum where statementes aren't as robust
  # `Third.where(status: ['active', 'inactive'])` does not work
  test 'basic filtering by enum works' do
    query = <<-GRAPHQL
      query($statuses: [ThirdStatuses!]) {
        thirdConnection(where: { status_in: $statuses }) {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      statuses: %w[active inactive],
    }

    resp = @schema.execute(query, variables: variables)

    nodes = resp['data']['thirdConnection']['nodes']
    node_ids = nodes.map { |node| node['id'] }

    assert_equal 2, nodes.length

    assert_includes node_ids, @third_b.id
    assert_includes node_ids, @third_c.id
  end

  test 'invalid enum option errors' do
    query = <<-GRAPHQL
      query($status: ThirdStatuses) {
        thirdConnection(where: { status: $status }) {
          nodes {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      status: 'invalid',
    }

    resp = @schema.execute(query, variables: variables)

    assert_nil resp['data']
  end
end
