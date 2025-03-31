# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "herd"
  spec.version       = "0.1.0"
  spec.authors       = ["John Koisch"]
  spec.email         = ["simon_jester_jr@protonmail.com"]

  spec.summary       = "A workflow management system"
  spec.description   = "Herd is a powerful workflow management system that helps you organize and execute complex workflows"
  spec.homepage      = "https://github.com/yourusername/herd"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{bin,lib}/**/*")
  spec.require_paths = ["lib"]

  spec.add_dependency "graphviz", "~> 1.4"
  spec.add_dependency "hiredis", "~> 0.6"
  spec.add_dependency "redis", "~> 4.0"
  spec.add_dependency "oj", "~> 3.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end 