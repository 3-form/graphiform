require 'test_helper'

class GraphqlConnectionTest < ActiveSupport::TestCase
  test 'has graphql_connection available' do
    assert_respond_to First, :graphql_connection
    assert_not_empty First.graphql_connection.fields
    assert First.graphql_connection.fields['pageInfo']
    assert First.graphql_connection.fields['edges']
    assert First.graphql_connection.fields['nodes']
  end

  test 'graphql_connection edge and node types are correct' do
    assert_equal First.graphql_edge, First.graphql_connection.fields['edges'].type.of_type
    assert_equal First.graphql_type, First.graphql_connection.fields['edges'].type.of_type.fields['node'].type
    assert_equal First.graphql_type, First.graphql_connection.fields['nodes'].type.of_type
  end
end
