require 'test_helper'

class Graphiform::Test < ActiveSupport::TestCase
  test 'truth' do
    assert_kind_of Module, Graphiform
  end

  test 'scopiform is included' do
    assert_respond_to First, :auto_scopes
    assert_not_empty First.auto_scopes
  end

  # removing for now as this should probably be tested in scopiform not graphiform
  # test 'does not throw on missing table' do
  #   NoTable.graphql_type
  #   NoTable.graphql_input
  #   NoTable.graphql_query
  #   NoTable.graphql_connection_query
  # end
end
