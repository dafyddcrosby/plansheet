# frozen_string_literal: true

require "pathname"
require "rgl/adjacency"
require "rgl/topsort"

module Plansheet
  # The "pool" is the aggregated collection of projects, calendar events, etc.
  class Pool
    attr_accessor :projects

    DEFAULT_COMPARISON_ORDER = %w[
      completeness
      completed_on
      dependency
      priority
      defer
      due
      time_roi
      status
      name
    ].freeze

    def initialize(config, debug: false)
      @projects_dir = config[:projects_dir]
      @sort_order = config[:sort_order]

      # This bit of trickiness is because we don't know what the sort order is
      # until runtime. I'm sure this design decision definitely won't bite me
      # in the future ;-) Fortunately, it's also not a problem that can't be
      # walked back from.
      # rubocop:disable Lint/OrAssignmentToConstant
      Plansheet::Pool::POOL_COMPARISON_ORDER ||= config[:sort_order] if config[:sort_order]
      puts "using config sort order" if config[:sort_order]
      Plansheet::Pool::POOL_COMPARISON_ORDER ||= Plansheet::Pool::DEFAULT_COMPARISON_ORDER
      # rubocop:enable Lint/OrAssignmentToConstant
      require_relative "project"

      load_projects_dir(@projects_dir) unless debug
      sort_projects if @projects
    end

    def sort_projects
      @projects ||= []
      @projects.sort!
      # lookup_hash returns the index of a project
      lookup_hash = Hash.new nil

      # initialize the lookups
      @projects.each_index do |i|
        lookup_hash[@projects[i].name] = i
      end

      pg = RGL::DirectedAdjacencyGraph.new
      pg.add_vertices @projects
      @projects.each_index do |proj_index|
        next if @projects[proj_index].dropped_or_done?

        @projects[proj_index]&.dependencies&.each do |dep|
          di = lookup_hash[dep]
          next unless di
          # Don't add edges for dropped/done projects, they'll be sorted out
          # later
          next if @projects[di].dropped_or_done?

          pg.add_edge(@projects[di], @projects[proj_index])
        end
      end

      # The topological sort of pg is the correct dependency order of the
      # projects
      @projects = pg.topsort_iterator.to_a.flatten.uniq

      # TODO: second sort doesn't deal with problems where deferred task gets
      # pushed below.
      @projects.sort!
    end

    def archive_projects
      archive_dir = "#{@projects_dir}/archive/"
      FileUtils.mkdir_p archive_dir

      # NOTE: It would save writes if we sorted and did all month/namespaces
      # writes only once, but as the normal case only sees a few projects
      # archived at a time, I'll leave that for someone else to implement ;-)
      projects_to_archive = @projects.select(&:archivable?)
      projects_to_archive.each do |project|
        path = Pathname.new "#{archive_dir}/#{project.archive_month}/#{project.namespace}.yml"
        Dir.mkdir path.dirname unless path.dirname.exist?
        pyf = ProjectYAMLFile.new path
        pyf.append_project project
      end

      # Now that the projects have been archived, remove them from the pool
      @projects.reject!(&:archivable?)
    end

    def project_namespaces
      @projects.collect(&:namespace).uniq.sort
    end

    def projects_in_namespace(namespace)
      @projects.select { |x| x.namespace == namespace }
    end

    def write_projects
      # Collect the namespaces *before* archiving is done, for the case where
      # all active projects in a namespace have been completed and archived
      namespaces_before_archiving = project_namespaces

      archive_projects

      namespaces_before_archiving.each do |ns|
        projects = projects_in_namespace(ns)
        pyf = ProjectYAMLFile.new "#{@projects_dir}/#{ns}.yml"
        pyf.compare_and_write projects
      end
    end

    def load_projects_dir(dir)
      projects = Dir.glob("*yml", base: dir)
      project_arr = projects.map do |l|
        ProjectYAMLFile.new(File.join(dir, l)).load_file
      end

      @projects = project_arr.flatten!
    end
  end
end
