require 'test_helper'

class GraphqlSortTest < ActiveSupport::TestCase
  test 'has graphql_sort available' do
    assert_respond_to First, :graphql_sort
    assert_not_empty First.graphql_sort.arguments
  end

  test 'does not have OR sorting' do
    assert_not First.graphql_sort.arguments['OR']
  end

  test 'has correct type for each graphql_sort argument' do
    assert_equal 10, First.graphql_sort.arguments.count

    assert_equal ::Graphiform::SortEnum, First.graphql_sort.arguments['name'].type
  end
end
