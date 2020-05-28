require 'test_helper'

class GraphqlTypeTest < ActiveSupport::TestCase
  test 'has graphql_type available' do
    assert_respond_to First, :graphql_type
    assert_not_empty First.graphql_type.fields
  end

  test 'has correct type for each graphql_type field' do
    assert_equal GraphQL::Types::String, First.graphql_type.fields['name'].type
    assert_equal GraphQL::Types::ISO8601Date, First.graphql_type.fields['date'].type
    assert_equal GraphQL::Types::Int, First.graphql_type.fields['number'].type
    assert_equal GraphQL::Types::Boolean, First.graphql_type.fields['boolean'].type
    assert_equal GraphQL::Types::ISO8601DateTime, First.graphql_type.fields['updatedAt'].type.of_type
    assert First.graphql_type.fields['updatedAt'].type.non_null?
    assert_equal GraphQL::Types::ISO8601DateTime, First.graphql_type.fields['createdAt'].type.of_type
    assert First.graphql_type.fields['createdAt'].type.non_null?
  end
end
