require 'test_helper'

class GraphqlFilterTest < ActiveSupport::TestCase
  test 'has graphql_filter available' do
    assert_respond_to First, :graphql_filter
    assert_not_empty First.graphql_filter.arguments
  end

  test 'has OR filter' do
    argument = First.graphql_filter.arguments['OR']

    assert argument
    assert_kind_of GraphQL::Schema::List, argument.type
    assert_kind_of GraphQL::Schema::NonNull, argument.type.of_type
    assert_equal First.graphql_filter, argument.type.of_type.of_type
  end

  test 'does not include sort_by_ filters' do
    assert_not First.graphql_filter.arguments['sort_by_name']
  end
end
