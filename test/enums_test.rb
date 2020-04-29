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

    third_mutation = Class.new(GraphQL::Schema::RelayClassicMutation) do
      graphql_name 'test_third_mutation'

      argument :attributes, Third.graphql_input, required: true

      field :third, Third.graphql_type, null: false

      def resolve(**_kargs)
        { third: Third.first }
      end
    end

    mutation = Class.new(::Types::BaseObject) do
      graphql_name 'test_mutation'
      field :mutateThird, mutation: third_mutation
    end

    @third_mutation = third_mutation
    @schema = Class.new(GraphQL::Schema) do
      query(query)
      mutation(mutation)
    end
  end

  test 'enums get correct graphql type' do
    assert_equal Enums::ThirdStatuses, Third.graphql_type.fields['status'].type
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

  test 'enum input accepts valid options' do
    resolve_spy = Spy.on_instance_method(@third_mutation, :resolve).and_return({ third: @third_b })

    mutation = <<-GRAPHQL
      mutation($input: test_third_mutationInput!) {
        mutateThird(input: $input) {
          third {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      input: {
        attributes: {
          name: 'derp',
          status: 'discontinued',
        },
      },
    }

    resp = @schema.execute(mutation, variables: variables)

    assert_equal @third_b.id, resp['data']['mutateThird']['third']['id']

    assert_equal 1, resolve_spy.calls.length
    assert_equal 1, resolve_spy.calls.first.args.length
    attributes = resolve_spy.calls.first.args.first[:attributes].to_h

    assert_equal 'derp', attributes[:name]
    assert_equal 'discontinued', attributes[:status]
  end

  test 'enum input does not accept invalid options' do
    mutation = <<-GRAPHQL
      mutation($input: test_third_mutationInput!) {
        mutateThird(input: $input) {
          third {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      input: {
        attributes: {
          name: 'derp',
          status: 'bad status',
        },
      },
    }

    resp = @schema.execute(mutation, variables: variables)

    assert_not resp['data']
    assert resp['errors']
  end
end
