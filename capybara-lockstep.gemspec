require_relative "lib/capybara-lockstep/version"

Gem::Specification.new do |spec|
  spec.name          = "capybara-lockstep"
  spec.version       = Capybara::Lockstep::VERSION
  spec.authors       = ["Henning Koch"]
  spec.email         = ["henning.koch@makandra.de"]
  spec.homepage      = "https://github.com/makandra/capybara-lockstep"
  spec.summary       = "Synchronize Capybara commands with client-side JavaScript and AJAX requests"
  spec.license       = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => 'true',
  }

  spec.files = `git ls-files`.split("\n").select { |f| !File.symlink?(f) && !f.match(%r{^(spec|dev|media|.github)/}) }
  spec.require_paths = ["lib"]

  spec.bindir        = "exe"
  spec.executables   = []

  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.add_dependency "capybara", ">= 3.0"
  spec.add_dependency "activesupport", ">= 7.0"
end
