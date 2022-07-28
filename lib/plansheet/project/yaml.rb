# frozen_string_literal: true

require "yaml"
require "date"
require "pathname"

require "diffy"
require "kwalify"

module Plansheet
  # Once there's some stability in plansheet and dc-kwalify, will pre-load this
  # to save the later YAML.load
  YAML_TIME_REGEX = "/\\d+[mh] ?\d*m?/" # TODO: regex is bad, adjust for better handling of pretty time
  YAML_DATE_REGEX = "/\\d+[dw]/"
  PROJECT_YAML_SCHEMA = <<~YAML
    desc: dc-tasks project schema
    type: seq
    sequence:
      - type: map
        mapping:
          "project":
            desc: Project name
            type: str
            unique: true
          "namespace":
            desc: Project name
            type: str
          "priority":
            desc: Project priority
            type: str
            enum:
              - high
              - medium
              - low
          "status":
            desc: The current status of the project
            type: str
            enum:
              - wip # project is a work-in-progress
              - ready # project has tasks, ready to go
              - waiting # project in waiting on some external person/event
              - blocked # project is blocked by another project, but otherwise ready/wip
              - planning # project in planning phase (set manually)
              - idea # project is little more than an idea
              - dropped # project has been explicitly dropped, but
                        # want to keep around for reference, etc
              - done # project is finished, but want to keep around
                     # for reference, etc.
          "location":
            desc: Location
            type: str
          "notes":
            desc: Free-form notes string
            type: str
          "time_estimate":
            desc: The estimated amount of time before a project is completed
            type: str
            pattern: #{YAML_TIME_REGEX}
          "daily_time_roi":
            desc: The estimated amount of time saved daily by completing this project
            type: str
            pattern: #{YAML_TIME_REGEX}
          "weekly_time_roi":
            desc: The estimated amount of time saved daily by completing this project
            type: str
            pattern: #{YAML_TIME_REGEX}
          "yearly_time_roi":
            desc: The estimated amount of time saved daily by completing this project
            type: str
            pattern: #{YAML_TIME_REGEX}
          "day_of_week":
            desc: recurring day of week project
            type: str
            enum:
              - Sunday
              - Monday
              - Tuesday
              - Wednesday
              - Thursday
              - Friday
              - Saturday
          "frequency":
            desc: The amount of time before a recurring project moves to ready status again from when it was last done, with a set due date (eg. a bill becomes due)
            type: str
            pattern: #{YAML_DATE_REGEX}
          "last_for":
            desc: "The amount of time before a recurring project moves to ready status again from when it was last done, with a set defer date (eg. inflating a bike tire). If your project 'can't wait' a day or two, you should use frequency."
            type: str
            pattern: #{YAML_DATE_REGEX}
          "lead_time":
            desc: The amount of time before a recurring project is "due" moved to ready where the project (sort of a deferral mechanism) (WIP)
            type: str
            pattern: #{YAML_DATE_REGEX}
          "due":
            desc: Due date of the task
            type: date
          "defer":
            desc: Defer task until this day
            type: date
          "completed_on":
            desc: When the (non-recurring) project was completed
            type: date
          "dropped_on":
            desc: When the project was dropped
            type: date
          "created_on":
            desc: When the project was created
            type: date
          "starts_on":
            desc: For ICS (WIP)
            type: date
          "last_reviewed":
            desc: When the project was last reviewed (WIP)
            type: date
          "last_done":
            desc: When the recurring project was last completed (WIP)
            type: date
          "dependencies":
            desc: The names of projects that need to be completed before this project can be started/completed
            type: seq
            sequence:
              - type: str
          "externals":
            desc: List of external commitments, ie who else cares about project completion?
            type: seq
            sequence:
              - type: str
          "urls":
            desc: List of URLs that may be pertinent
            type: seq
            sequence:
              - type: str
          "tasks":
            desc: List of tasks to do
            type: seq
            sequence:
              - type: str
          "done":
            desc: List of tasks which have been completed
            type: seq
            sequence:
              - type: str
          "tags":
            desc: List of tags (WIP)
            type: seq
            sequence:
              - type: str
  YAML
  PROJECT_SCHEMA = YAML.safe_load(PROJECT_YAML_SCHEMA)

  class ProjectYAMLFile
    attr_accessor :projects

    def initialize(path)
      @path = path
      # TODO: this won't GC, inline validation instead?
    end

    def stub_file
      File.write @path, YAML.dump([])
    end

    def load_file
      stub_file unless File.exist? @path

      # Handle pre-Ruby 3.1 psych versions (this is brittle)
      @raw = if Psych::VERSION.split(".")[0].to_i >= 4
               YAML.load_file(@path, permitted_classes: [Date])
             else
               YAML.load_file(@path)
             end

      validate_schema
      @raw ||= []
      @projects = @raw.map do |proj|
        proj["namespace"] = namespace
        Project.new proj
      end
      @projects
    end

    def namespace
      # TODO: yikes
      ::Pathname.new(@path).basename.to_s.gsub(/\.yml$/, "")
    end

    def validate_schema
      validator = Kwalify::Validator.new(Plansheet::PROJECT_SCHEMA)
      errors = validator.validate(@raw)
      # Check YAML validity
      return unless errors && !errors.empty?

      $stderr.write "Schema errors in #{@path}:\n"
      errors.each { |err| puts "- [#{err.path}] #{err.message}" }
      abort
    end

    def sort!
      @projects.sort!
    end

    def append_project(project)
      load_file
      compare_and_write(@projects.append(project))
    end

    def compare_and_write(projects)
      load_file
      orig_string = yaml_dump(@projects)
      updated_projects_string = yaml_dump(projects)

      # Compare the existing file to the newly generated one - we only want a
      # write if something has changed
      return if updated_projects_string == orig_string

      puts "#{@path} has changed, writing"
      puts Diffy::Diff.new(orig_string, updated_projects_string).to_s(:color)
      File.write @path, updated_projects_string
    end

    def yaml_dump(projects)
      # binding.irb if projects.nil?
      YAML.dump(projects.map do |x|
        x.to_h.delete_if do |k, v|
          # Remove low-value default noise from projects
          k == "namespace" ||
           (k == "priority" && v == "low") ||
           (k == "status" && v == "idea")
        end
      end)
    end
  end
end
