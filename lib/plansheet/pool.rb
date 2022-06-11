# frozen_string_literal: true

module Plansheet
  # The "pool" is the aggregated collection of projects, calendar events, etc.
  class Pool
    attr_accessor :projects

    def initialize(config)
      @projects_dir = config[:projects_dir]
      # @completed_projects_dir = config(:completed_projects_dir)

      load_projects_dir(@projects_dir)
      sort_projects
    end

    def sort_projects
      @projects.sort!
    end

    def project_namespaces
      @projects.collect(&:namespace).uniq.sort
    end

    def projects_in_namespace(namespace)
      @projects.select { |x| x.namespace == namespace }
    end

    def write_projects
      # TODO: This leaves potential for duplicate projects where empty files
      # are involved once completed project directories are a thing - will need
      # to keep a list of project files to delete
      project_namespaces.each do |ns|
        pyf = ProjectYAMLFile.new "#{@projects_dir}/#{ns}.yml"
        pyf.projects = projects_in_namespace(ns)
        pyf.write
      end
    end

    def load_projects_dir(dir)
      project_arr = []
      projects = Dir.glob("*yml", base: dir)
      projects.each do |l|
        project_arr << ProjectYAMLFile.new(File.join(dir, l)).load_file
      end

      @projects = project_arr.flatten!
    end
  end
end
