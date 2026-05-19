# test/dataloader_test.rb
require 'test_helper'

class DataloaderTest < ActiveSupport::TestCase
  setup do
    @firsts = 3.times.map { |i| First.create!(name: "first-#{i}") }
    @firsts.each do |f|
      2.times { |i| Second.create!(first: f, name: "second-#{f.id}-#{i}") }
    end

    query_type = Class.new(::Types::BaseObject) do
      graphql_name 'DataloaderTestQuery'
      field :firstConnection, resolver: First.graphql_connection_query
    end

    @schema = Class.new(GraphQL::Schema) do
      query(query_type)
      use GraphQL::Dataloader
    end
  end

  # ── Batching ──

  test 'has_many association batches into one fetch via dataloader' do
    fetch_counts = []
    trace = Module.new do
      define_method(:fetch) do |records|
        fetch_counts << records.length
        super(records)
      end
    end
    Graphiform::PreloaderSource.prepend(trace)

    query = <<~GRAPHQL
      query { firstConnection { nodes { id seconds { id } } } }
    GRAPHQL

    resp = @schema.execute(query)

    assert_nil resp['errors'], "Query had errors: #{resp['errors'].inspect}"
    assert_equal 1, fetch_counts.length,
      "Expected 1 batched fetch, got #{fetch_counts.length}: #{fetch_counts.inspect}"
    assert_equal @firsts.length, fetch_counts.first
  end

  test 'batched association returns correct data' do
    query = <<~GRAPHQL
      query { firstConnection { nodes { id seconds { id } } } }
    GRAPHQL

    resp = @schema.execute(query)
    nodes = resp['data']['firstConnection']['nodes']

    assert_equal @firsts.length, nodes.length
    nodes.each do |node|
      expected_ids = Second.where(first_id: node['id']).pluck(:id).sort
      actual_ids   = node['seconds'].map { |s| s['id'] }.sort
      assert_equal expected_ids, actual_ids
    end
  end

  test 'query count does not scale with number of parents' do
    query = <<~GRAPHQL
      query { firstConnection { nodes { id seconds { id } } } }
    GRAPHQL

    queries_small = count_select_queries { @schema.execute(query) }
    small_seconds = queries_small.count { |q| q =~ /\bFROM\s+["']?seconds/i }

    5.times do |i|
      f = First.create!(name: "extra-#{i}")
      2.times { |j| Second.create!(first: f, name: "extra-#{i}-#{j}") }
    end

    queries_large = count_select_queries { @schema.execute(query) }
    large_seconds = queries_large.count { |q| q =~ /\bFROM\s+["']?seconds/i }

    assert_equal small_seconds, large_seconds,
      "Query count for seconds scaled with parent count — N+1 detected"
  end

  # ── Skip-dataloader: read_prepare ──

  test 'skips dataloader when read_prepare is present' do
    fetch_counts = []
    trace = Module.new do
      define_method(:fetch) do |records|
        fetch_counts << records.length
        super(records)
      end
    end
    Graphiform::PreloaderSource.prepend(trace)

    query = <<~GRAPHQL
      query { firstConnection { nodes { id secondsWithPrepare { id name } } } }
    GRAPHQL

    resp = @schema.execute(query)

    assert_nil resp['errors'], "Query had errors: #{resp['errors'].inspect}"
    # read_prepare forces skip — no PreloaderSource fetch
    assert_equal 0, fetch_counts.length, "Expected no batched fetch when read_prepare is present"

    # Verify the read_prepare filter was applied
    resp['data']['firstConnection']['nodes'].each do |node|
      node['secondsWithPrepare'].each do |s|
        assert s['name'].end_with?('-0'), "read_prepare filter not applied: #{s['name']}"
      end
    end
  end

  # ── PreloaderSource unit tests ──

  test 'PreloaderSource.build_scope returns nil when klass is nil' do
    assert_nil Graphiform::PreloaderSource.build_scope(nil, where: { name: 'x' })
  end

  test 'PreloaderSource.build_scope returns relation when scope is present' do
    scope_proc = -> { where(name: 'test') }
    result = Graphiform::PreloaderSource.build_scope(Second, scope: scope_proc)
    assert_kind_of ActiveRecord::Relation, result
  end

  test 'PreloaderSource.build_scope returns nil when no customization' do
    assert_nil Graphiform::PreloaderSource.build_scope(Second)
  end

  test 'PreloaderSource.build_scope returns relation when includes is present' do
    result = Graphiform::PreloaderSource.build_scope(Second, includes: :first)
    assert_kind_of ActiveRecord::Relation, result
  end

  test 'PreloaderSource.build_scope returns relation when where is present' do
    result = Graphiform::PreloaderSource.build_scope(Second, where: { name_is: 'test' })
    assert_kind_of ActiveRecord::Relation, result
  end

  # ── Helpers.dataloader_support? unit tests ──

  test 'dataloader_support? returns false for NullDataloader' do
    null_dl = GraphQL::Dataloader::NullDataloader.new
    assoc   = First.reflect_on_association(:seconds)
    refute Graphiform::Helpers.dataloader_support?(null_dl, assoc)
  end

  test 'dataloader_support? returns false when association_def is nil' do
    dl = GraphQL::Dataloader.new
    refute Graphiform::Helpers.dataloader_support?(dl, nil)
  end

  test 'dataloader_support? returns true for valid non-polymorphic association' do
    dl    = GraphQL::Dataloader.new
    assoc = First.reflect_on_association(:seconds)
    assert Graphiform::Helpers.dataloader_support?(dl, assoc)
  end
end
