require 'test_helper'

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @original_config = Graphiform.configuration.dup
  end

  teardown do
    Graphiform.instance_variable_set(:@configuration, @original_config)
  end

  test 'configure yields the configuration hash' do
    yielded = nil
    Graphiform.configure { |c| yielded = c }
    assert_same Graphiform.configuration, yielded
  end

  test 'field_class override is applied to generated types' do
    custom_field_class    = Class.new(GraphQL::Schema::Field)
    custom_argument_class = Class.new(GraphQL::Schema::Argument)

    Graphiform.configure do |c|
      c[:field_class]    = custom_field_class
      c[:argument_class] = custom_argument_class
    end

    klass = Class.new(ApplicationRecord) do
      self.table_name = 'firsts'

      def self.name
        'ConfigFirst'  # unique demodulized_name → unique ::Types::ConfigFirst
      end

      include Graphiform
      graphql_fields :name, writable: true
    end

    assert_equal custom_field_class, klass.graphql_type.field_class
    assert_equal custom_argument_class, klass.graphql_input.argument_class
  end

  test 'configuring field_class without argument_class raises' do
    assert_raises(GraphiformConfigurationError) do
      Graphiform.configure { |c| c[:field_class] = Class.new(GraphQL::Schema::Field) }
    end
  end

  test 'configuring argument_class without field_class raises' do
    assert_raises(GraphiformConfigurationError) do
      Graphiform.configure { |c| c[:argument_class] = Class.new(GraphQL::Schema::Argument) }
    end
  end
end
