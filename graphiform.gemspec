$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "graphiform/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "graphiform"
  spec.version     = Graphiform::VERSION
  spec.authors     = ["jayce.pulsipher"]
  spec.email       = ["jayce.pulsipher@3-form.com"]
  spec.homepage    = ""
  spec.summary     = " Summary of Graphiform."
  spec.description = " Description of Graphiform."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 5.2.3"
  spec.add_dependency "graphql", "~> 1.10"

  spec.add_runtime_dependency "scopiform"

  spec.add_development_dependency "sqlite3"
end
