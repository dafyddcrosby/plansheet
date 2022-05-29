# frozen_string_literal: true

require_relative "plansheet/version"
require_relative "plansheet/project"
require_relative "plansheet/sheet"
require "yaml"
require "kwalify"

module Plansheet
  class Error < StandardError; end

  def self.load_config
    YAML.load_file "#{Dir.home}/.plansheet.yml"
  rescue StandardError
    abort "unable to load plansheet config file"
  end

  def self.load_projects_file(path)
    contents = YAML.load_file(path)
    validator = Kwalify::Validator.new(Plansheet::PROJECT_SCHEMA)
    errors = validator.validate(contents)
    # Check YAML validity
    if errors && !errors.empty?
      $stderr.write "Schema errors in #{l}\n"
      errors.each { |err| puts "- [#{err.path}] #{err.message}" }
      abort
    end
    arr = []
    contents.each do |project|
      arr << Plansheet::Project.new(project)
    end
    arr
  end
end
