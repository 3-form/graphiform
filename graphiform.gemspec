$:.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'graphiform/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'graphiform'
  spec.version     = Graphiform::VERSION
  spec.authors     = ['jayce.pulsipher']
  spec.email       = ['jayce.pulsipher@3-form.com']
  spec.homepage    = 'https://github.com/3-form/graphiform'
  spec.summary     = 'Generate GraphQL types, inputs, resolvers, queries, and connections based off whitelisted column and association definitions'
  # spec.description = ' Description of Graphiform.'
  spec.license     = 'MIT'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  spec.add_runtime_dependency 'activerecord', '>= 4.2.7'
  spec.add_runtime_dependency 'graphql', '~> 1.8'
  spec.add_runtime_dependency 'scopiform', '~> 0.2.9'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'spy'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'warning'
end
