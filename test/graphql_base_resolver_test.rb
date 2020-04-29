require 'test_helper'

class GraphqlBaseResolverTest < ActiveSupport::TestCase
  test 'has graphql_base_resolver available' do
    assert_respond_to First, :graphql_base_resolver
    assert_not_empty First.graphql_base_resolver.arguments

    assert First.graphql_base_resolver.arguments['where']
    assert_equal First.graphql_filter, First.graphql_base_resolver.arguments['where'].type
    assert First.graphql_base_resolver.arguments['sort']
    assert_equal First.graphql_sort, First.graphql_base_resolver.arguments['sort'].type
  end
end
