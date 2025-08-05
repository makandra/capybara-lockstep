require_relative "lib/capybara-lockstep/version"

Gem::Specification.new do |spec|
  spec.name          = "capybara-lockstep"
  spec.version       = Capybara::Lockstep::VERSION
  spec.authors       = ["Henning Koch"]
  spec.email         = ["henning.koch@makandra.de"]

  spec.summary       = "Synchronize Capybara commands with client-side JavaScript and AJAX requests"
  spec.homepage      = "https://github.com/makandra/capybara-lockstep"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.metadata["bug_tracker_uri"] = "https://github.com/makandra/capybara-lockstep/issues"
  spec.metadata["changelog_uri"] = "https://github.com/makandra/capybara-lockstep/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "capybara", ">= 3.0"
  spec.add_dependency "activesupport", ">= 4.2"
  spec.add_dependency "ruby2_keywords"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
