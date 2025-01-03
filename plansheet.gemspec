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

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "dc-kwalify", "~>1.0"
  spec.add_dependency "diffy", "= 3.4.2"
  spec.add_dependency "rgl", "= 0.5.8"
end
