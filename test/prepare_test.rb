require 'test_helper'

class PrepareTest < ActiveSupport::TestCase
  setup do
    @first_a = First.create(name: 'abc', date: '2010-10-05', number: 5, boolean: true)
    @first_b = First.create(name: 'ghi', date: '2020-04-10', number: 20, boolean: true)
    @first_c = First.create(name: 'def', date: '2020-05-10', number: 10, boolean: false)

    @second_a = Second.create(first: @first_a, name: 'jayce', number: 10.82, datetime: '2020-03-16 21:17:20')
    @second_b = Second.create(first: @first_b, name: 'bailey', number: 8, datetime: '2020-03-16 1:17:20')
    @second_c = Second.create(first: @first_c, name: 'shane', number: 9.5, datetime: '2020-03-16 10:17:20')

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :second, resolver: Second.graphql_query
    end

    second_mutation = Class.new(GraphQL::Schema::RelayClassicMutation) do
      graphql_name 'test_second_mutation'

      argument :attributes, Second.graphql_input, required: true

      field :second, Second.graphql_type, null: false

      def resolve(**_kargs)
        { second: Second.first }
      end
    end

    mutation = Class.new(::Types::BaseObject) do
      graphql_name 'test_mutation'
      field :mutateSecond, mutation: second_mutation
    end

    @second_mutation = second_mutation
    @schema = Class.new(GraphQL::Schema) do
      query(query)
      mutation(mutation)
    end
  end

  test 'read_prepare modifies the method value' do
    query = <<-GRAPHQL
      query($id: Int) {
        second(where: { id: $id }) {
          id
          translateThis
        }
      }
    GRAPHQL
    variables = {
      id: @second_b.id,
    }

    resp = @schema.execute(query, variables: variables)
    item = resp['data']['second']

    assert_equal "-#{@second_b.id}:#{@second_b.name}-", item['translateThis']
  end

  test 'write_prepare modifies the value coming in' do
    resolve_spy = Spy.on_instance_method(@second_mutation, :resolve).and_return({ second: @second_b })

    mutation = <<-GRAPHQL
      mutation($input: test_second_mutationInput!) {
        mutateSecond(input: $input) {
          second {
            id
            translateThis
          }
        }
      }
    GRAPHQL
    variables = {
      input: {
        attributes: {
          name: 'derp',
          translateThis: 'abcdefg',
        },
      },
    }

    @schema.execute(mutation, variables: variables)

    assert_equal 1, resolve_spy.calls.length
    assert_equal 1, resolve_spy.calls.first.args.length
    attributes = resolve_spy.calls.first.args.first[:attributes].to_h

    assert_equal 'derp', attributes[:name]
    assert_equal 'gfedcba', attributes[:translate_this]
  end
end
