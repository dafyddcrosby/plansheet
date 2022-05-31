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

  def self.resort_projects_in_dir(dir)
    project_files = Dir.glob("#{dir}/*yml")
    project_files.each do |f|
      pyf = ProjectYAMLFile.new(f)
      pyf.sort!
      File.write(f, pyf.yaml_dump)
    end
  end

  def self.load_projects_dir(dir)
    project_arr = []
    projects = Dir.glob("*yml", base: dir)
    projects.each do |l|
      project_arr << ProjectYAMLFile.new(File.join(dir, l)).projects
    end

    project_arr.flatten!
  end
end
