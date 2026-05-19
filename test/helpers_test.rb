require 'test_helper'
require 'minitest/mock'

class HelpersBranchCoverageTest < ActiveSupport::TestCase
  # ── logger fallback (lines 8, 10-11) ──

  test 'Helpers.logger falls back to stdout logger when Rails.logger is nil' do
    original = Rails.logger
    begin
      Rails.logger = nil
      Graphiform::Helpers.instance_variable_set(:@logger, nil)
      logger = Graphiform::Helpers.logger
      assert_kind_of Logger, logger
    ensure
      Rails.logger = original
    end
  end

  # ── association_arguments_valid? false branches (lines 97-98) ──

  test 'association_arguments_valid? returns false when association_def is nil' do
    refute Graphiform::Helpers.association_arguments_valid?(nil, :graphql_type)
  end

  test 'association_arguments_valid? returns false when klass does not respond to method' do
    association_def = First.reflect_on_association(:seconds)
    refute Graphiform::Helpers.association_arguments_valid?(association_def, :nonexistent_method)
  end

  test 'association_arguments_valid? returns false when target has no own_arguments' do
    association_def = First.reflect_on_association(:seconds)
    refute Graphiform::Helpers.association_arguments_valid?(association_def, :graphql_type)
  end

  # ── dataloader_support? with polymorphic inverse_of (line 108) ──

  test 'dataloader_support? returns false when inverse_of is polymorphic' do
    dl = GraphQL::Dataloader.new

    inverse = Minitest::Mock.new
    inverse.expect(:polymorphic?, true)

    association_def = Minitest::Mock.new
    association_def.expect(:present?, true)
    association_def.expect(:polymorphic?, false)
    association_def.expect(:inverse_of, inverse)

    refute Graphiform::Helpers.dataloader_support?(dl, association_def)

    association_def.verify
    inverse.verify
  end
end
