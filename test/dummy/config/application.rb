require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require 'graphiform'

module Dummy
  class Application < Rails::Application
    # Load defaults matching the running Rails version so each appraisal
    # cell exercises the framework's expected baseline behavior.
    config.load_defaults Rails::VERSION::STRING.to_f

    config.eager_load = false

    # Engines under test don't need credential lookups.
    config.secret_key_base = 'graphiform-dummy-test-key' if config.respond_to?(:secret_key_base=)
  end
end