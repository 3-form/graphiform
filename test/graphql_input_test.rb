require 'test_helper'

class GraphqlInputTest < ActiveSupport::TestCase
  test 'has graphql_input available' do
    assert_respond_to First, :graphql_input
    assert_not_empty First.graphql_input.arguments
  end

  test 'has correct argument for each graphql_input field' do
    assert_equal 8, First.graphql_input.arguments.count

    assert_equal GraphQL::Types::String, First.graphql_input.arguments['name'].type
    assert_equal GraphQL::Types::ISO8601Date, First.graphql_input.arguments['date'].type
    assert_equal GraphQL::Types::Int, First.graphql_input.arguments['number'].type
    assert_equal GraphQL::Types::Boolean, First.graphql_input.arguments['boolean'].type
  end
end
