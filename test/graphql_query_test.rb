require 'test_helper'

class GraphqlQueryTest < ActiveSupport::TestCase
  setup do
    @first_a = First.create(name: 'abc', date: '2010-10-05', number: 5, boolean: true)
    @first_b = First.create(name: 'def', date: '2020-05-10', number: 10, boolean: false)
    @first_c = First.create(name: 'ghi', date: '2020-04-10', number: 20, boolean: true)

    @second_a = Second.create(first: @first_a, name: 'jayce', number: 10.82, datetime: '2020-03-16 21:17:20')
    @second_b = Second.create(first: @first_b, name: 'bailey', number: 8, datetime: '2020-03-16 1:17:20')
    @second_c = Second.create(first: @first_c, name: 'shane', number: 9.5, datetime: '2020-03-16 10:17:20')

    query = Class.new(::Types::BaseObject) do
      graphql_name 'test_query'
      field :first, resolver: First.graphql_query
    end

    first_mutation = Class.new(GraphQL::Schema::RelayClassicMutation) do
      graphql_name 'test_first_mutation'

      argument :attributes, First.graphql_input, required: true

      field :first, First.graphql_type, null: false

      def resolve(**_kargs)
        { first: First.first }
      end
    end

    mutation = Class.new(::Types::BaseObject) do
      graphql_name 'test_mutation'
      field :mutateFirst, mutation: first_mutation
    end

    @first_mutation = first_mutation
    @schema = Class.new(GraphQL::Schema) do
      query(query)
      mutation(mutation)
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
        first(where: { nameStartsWith: $name_starts_with }) {
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

  test 'using as resolves to the correct property' do
    query = <<-GRAPHQL
      query($id: Int) {
        first(where: { aliasId: $id }) {
          id
          aliasId
        }
      }
    GRAPHQL
    variables = {
      id: @first_b.id,
    }

    resp = @schema.execute(query, variables: variables)

    assert_equal @first_b.id, resp['data']['first']['id']
    assert_equal @first_b.id, resp['data']['first']['aliasId']
  end

  test 'using as resolves to the correct association' do
    query = <<-GRAPHQL
      query($id: Int) {
        first(where: { aliasSeconds: { id: $id } }) {
          id
          aliasSeconds {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      id: @second_b.id,
    }

    resp = @schema.execute(query, variables: variables)

    assert_equal @first_b.id, resp['data']['first']['id']
    assert_equal @second_b.id, resp['data']['first']['aliasSeconds'].first['id']
  end

  test 'using as resolves to the correct method' do
    query = <<-GRAPHQL
      query($id: Int) {
        first(where: { aliasId: $id }) {
          id
          aliasBasicMethod
        }
      }
    GRAPHQL
    variables = {
      id: @first_b.id,
    }

    resp = @schema.execute(query, variables: variables)

    assert_equal @first_b.id, resp['data']['first']['id']
    assert_equal @first_b.basic_method, resp['data']['first']['aliasBasicMethod']
  end

  test 'using as resolves arguments correctly' do
    resolve_spy = Spy.on_instance_method(@first_mutation, :resolve).and_return({ first: @first_b })

    mutation = <<-GRAPHQL
      mutation($input: test_first_mutationInput!) {
        mutateFirst(input: $input) {
          first {
            id
          }
        }
      }
    GRAPHQL
    variables = {
      input: {
        attributes: {
          aliasId: 55,
          aliasSecondsAttributes: [ { name: 'derp' } ],
          aliasBasicMethod: 'hello world',
        },
      },
    }

    resp = @schema.execute(mutation, variables: variables)

    assert_equal @first_b.id, resp['data']['mutateFirst']['first']['id']

    assert_equal 1, resolve_spy.calls.length
    assert_equal 1, resolve_spy.calls.first.args.length
    attributes = resolve_spy.calls.first.args.first[:attributes].to_h

    assert_equal 55, attributes[:id]
    assert_equal 'derp', attributes[:seconds_attributes].first[:name]
    assert_equal 'hello world', attributes[:basic_method]
  end
end
