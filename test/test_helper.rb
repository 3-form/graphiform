# Configure Rails Environment
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  enable_coverage :branch
end

ENV['RAILS_ENV'] = 'test'

# Ignore a ton of warnings
require 'warning'
Gem.path.each do |path|
  Warning.ignore(//, path)
end
Warning.ignore(//, 'parser.y')
Warning.ignore(//, '(eval)')
Warning.ignore(//, '/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/forwardable.rb')

# Spy warnings
Warning.ignore(/previous definition of/)
Warning.ignore(%r{circular require considered harmful.*graphql/dataloader})

require_relative '../test/dummy/config/environment'
ActiveRecord::Migrator.migrations_paths = [File.expand_path('../test/dummy/db/migrate', __dir__)]
require 'rails/test_help'
require 'spy'

ActiveRecord::Migration.maintain_test_schema!
# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# ActiveRecord::Base.logger = Logger.new(STDOUT)

# require 'rails/test_unit/reporter'
# Rails::TestUnitReporter.executable = 'bin/test'

# # Load fixtures from the engine
# if ActiveSupport::TestCase.respond_to?(:fixture_path=)
#   ActiveSupport::TestCase.fixture_path = File.expand_path('fixtures', __dir__)
#   ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
#   ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + '/files'
#   ActiveSupport::TestCase.fixtures :all
# end

# test/test_helper.rb (or a support module)
def count_select_queries(&block)
  queries = []
  callback = ->(*, payload) {
    sql = payload[:sql]
    next if sql =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|SCHEMA|PRAGMA)/i
    next if payload[:name] == 'SCHEMA'
    queries << sql if sql =~ /\ASELECT/i
  }
  ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)
  queries
end
