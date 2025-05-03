# frozen_string_literal: true

require_relative "lib/plansheet/version"

Gem::Specification.new do |spec|
  spec.name = "plansheet"
  spec.version = Plansheet::VERSION
  spec.authors = ["David Crosby"]
  spec.email = ["dave@dafyddcrosby.com"]

  spec.summary = "Convert YAML project files into a nice PDF"
  spec.description = spec.summary
  spec.homepage = "https://dafyddcrosby.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = File.read("Manifest.txt").split
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "dc-kwalify", "~>1.0"
  spec.add_dependency "diffy", "= 3.4.2"
  spec.add_dependency "rgl", "= 0.5.8"
end
