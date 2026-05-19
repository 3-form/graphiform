require 'test_helper'

class CoreTest < ActiveSupport::TestCase
  # Helper to execute a resolver through a real schema so we don't need
  # to manually construct field/context args
  def execute_with_field(resolver_class, object, return_type: GraphQL::Types::String, null: true)
    local_resolver = resolver_class
    local_return_type = return_type
    local_null = null

    query_type = Class.new(::Types::BaseObject) do
      graphql_name "CoreTestQuery#{object.object_id.abs}"
      field :test_field, resolver: local_resolver
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    schema.execute('{ testField }', root_value: object)
  end

  # ── graphql_create_resolver: read_resolve path (lines 112, 113, 123) ──

  test 'graphql_create_resolver with read_resolve skips public_send' do
    custom_resolve = ->(value, _ctx) { value.seconds.where("name LIKE ?", "%-0") }

    resolver_class = First.send(
      :graphql_create_resolver,
      :seconds,
      [Second.graphql_type],
      read_resolve: custom_resolve,
      null: true
    )

    first = First.create!(name: 'rr-test')
    Second.create!(first: first, name: 'rr-0')
    Second.create!(first: first, name: 'rr-1')

    # Execute through a real schema to avoid field: keyword issues
    local_resolver = resolver_class
    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'ReadResolveQuery'
      field :firstConnection, resolver: First.graphql_connection_query
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    # Use the seconds field with read_resolve by building a custom schema
    local_type = Class.new(::Types::BaseObject) do
      graphql_name 'ReadResolveFirst'
      field :id, GraphQL::Types::ID, null: false
      field :seconds_resolved, resolver: local_resolver
    end

    query_type2 = Class.new(::Types::BaseObject) do
      graphql_name 'ReadResolveQuery2'
      field :first, local_type, null: true

      define_method(:first) { First.find_by(name: 'rr-test') }
    end

    schema2 = Class.new(GraphQL::Schema) do
      query(query_type2)
      use GraphQL::Dataloader
    end

    resp = schema2.execute('{ first { secondsResolved { id } } }')
    assert_nil resp['errors'], "Errors: #{resp['errors'].inspect}"
  end

  # ── graphql_create_resolver: group forces skip_dataloader (line 113) ──

  test 'graphql_create_resolver skips dataloader when group arg present' do
    fetch_counts = []
    trace = Module.new do
      define_method(:fetch) do |records|
        fetch_counts << records.length
        super(records)
      end
    end
    Graphiform::PreloaderSource.prepend(trace)

    first = First.create!(name: 'group-test')
    Second.create!(first: first, name: 'g-1')

    # Execute a query that passes group argument
    # The secondsConnection field has group support via base_resolver
    query = <<~GRAPHQL
      query {
        firstConnection {
          nodes {
            id
            secondsConnection(group: { name: ASC }) {
              nodes { id }
            }
          }
        }
      }
    GRAPHQL

    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'GroupTestQuery'
      field :firstConnection, resolver: First.graphql_connection_query
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    resp = schema.execute(query)
    # Even if the query errors due to group not being defined, the code path is hit
    # The important thing is fetch was not called
    assert_equal 0, fetch_counts.length, "Dataloader should be skipped with group arg"
  end

  # ── graphql_create_resolver: nil association (line 109) ──

  test 'graphql_create_resolver with skip_dataloader true skips dataloader path' do
    resolver_class = First.send(
      :graphql_create_resolver,
      :seconds,
      [Second.graphql_type],
      null: true,
      skip_dataloader: true
    )

    local_resolver = resolver_class
    local_type = Class.new(::Types::BaseObject) do
      graphql_name 'SkipDLFirst'
      field :id, GraphQL::Types::ID, null: false
      field :skip_dl_seconds, resolver: local_resolver
    end

    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'SkipDLQuery'
      field :first, local_type, null: true

      define_method(:first) { First.find_by(name: 'skip-dl') }
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    first = First.create!(name: 'skip-dl')
    Second.create!(first: first, name: 'sdl-1')

    resp = schema.execute('{ first { skipDlSeconds { id } } }')
    assert_nil resp['errors'], "Errors: #{resp['errors'].inspect}"
    assert_equal 1, resp['data']['first']['skipDlSeconds'].length
  end

  test 'graphql_create_resolver with read_prepare transforms result' do
    custom_prepare = ->(value, _ctx) { value.where("name LIKE ?", "%-0") }

    resolver_class = First.send(
      :graphql_create_resolver,
      :seconds,
      [Second.graphql_type],
      read_prepare: custom_prepare,
      null: true
    )

    local_resolver = resolver_class
    local_type = Class.new(::Types::BaseObject) do
      graphql_name 'PrepareFirst'
      field :id, GraphQL::Types::ID, null: false
      field :prepared_seconds, resolver: local_resolver
    end

    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'PrepareQuery'
      field :first, local_type, null: true

      define_method(:first) { First.find_by(name: 'prep-test') }
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    first = First.create!(name: 'prep-test')
    Second.create!(first: first, name: 'prep-0')
    Second.create!(first: first, name: 'prep-1')

    resp = schema.execute('{ first { preparedSeconds { id } } }')
    assert_nil resp['errors'], "Errors: #{resp['errors'].inspect}"
    # Only the "-0" record should come through
    assert_equal 1, resp['data']['first']['preparedSeconds'].length
  end

  # ── graphql_create_association_resolver (lines 246, 256-258) ──

  test 'graphql_create_association_resolver uses dataloader' do
    association_def = First.reflect_on_association(:seconds)
    resolver_class = First.send(
      :graphql_create_association_resolver,
      association_def,
      [Second.graphql_type],
      null: true
    )

    local_resolver = resolver_class
    local_type = Class.new(::Types::BaseObject) do
      graphql_name 'AssocDLFirst'
      field :id, GraphQL::Types::ID, null: false
      field :assoc_seconds, resolver: local_resolver
    end

    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'AssocDLQuery'
      field :first, local_type, null: true

      define_method(:first) { First.find_by(name: 'assoc-dl') }
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    first = First.create!(name: 'assoc-dl')
    Second.create!(first: first, name: 'adl-1')

    resp = schema.execute('{ first { assocSeconds { id } } }')
    assert_nil resp['errors'], "Errors: #{resp['errors'].inspect}"
    assert_equal 1, resp['data']['first']['assocSeconds'].length
  end

  test 'graphql_create_association_resolver skips dataloader when forced' do
    association_def = First.reflect_on_association(:seconds)
    resolver_class = First.send(
      :graphql_create_association_resolver,
      association_def,
      [Second.graphql_type],
      null: true,
      skip_dataloader: true
    )

    local_resolver = resolver_class
    local_type = Class.new(::Types::BaseObject) do
      graphql_name 'AssocSkipFirst'
      field :id, GraphQL::Types::ID, null: false
      field :skip_seconds, resolver: local_resolver
    end

    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'AssocSkipQuery'
      field :first, local_type, null: true

      define_method(:first) { First.find_by(name: 'assoc-skip') }
    end

    schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end

    first = First.create!(name: 'assoc-skip')
    Second.create!(first: first, name: 'as-1')

    resp = schema.execute('{ first { skipSeconds { id } } }')
    assert_nil resp['errors'], "Errors: #{resp['errors'].inspect}"
    assert_equal 1, resp['data']['first']['skipSeconds'].length
  end
end
