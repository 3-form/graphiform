# frozen_string_literal: true

# The dummy app intentionally defines top-level constants (Types, Inputs,
# Resolvers, Enums) created at runtime by Graphiform.create_skeleton. Tell
# Zeitwerk not to try to autoload them — they don't exist until the gem
# is included into a model.
Rails.autoloaders.main.do_not_eager_load(
  Rails.root.join('app', 'models')
) if Rails.application.config.respond_to?(:autoloaders)

# Silence Zeitwerk's warning about anonymous classes being assigned to
# top-level constants (Types::BaseObject, etc.) during tests.
Rails.autoloaders.each do |loader|
  loader.ignore(Rails.root.join('tmp')) if Rails.root.join('tmp').exist?
end