# frozen_string_literal: true

require "yaml"

module Plansheet
  PROJECT_STATUS_PRIORITY = {
    "wip" => 1,
    "ready" => 2,
    "blocked" => 3,
    "planning" => 4,
    "idea" => 5,
    "dropped" => 6,
    "done" => 7
  }.freeze

  # Once there's some stability in plansheet and dc-kwalify, will pre-load this
  # to save the later YAML.load
  PROJECT_YAML_SCHEMA = <<~YAML
    desc: dc-tasks project schema
    type: seq
    sequence:
      - type: map
        mapping:
          "project":
            desc: Project name
            type: str
            required: yes
          "status":
            desc: The current status of the project
            type: str
            enum:
              - wip # project is a work-in-progress
              - ready # project is fully scoped, ready to go
              - blocked # project is blocked, but otherwise ready/wip
              - planning # project in planning phase
              - idea # project is little more than an idea
              - dropped # project has been explicitly dropped, but
                        # want to keep around for reference, etc
              - done # project is finished, but want to keep around
                     # for reference, etc.
          "priority":
            desc: Project priority (not currently implemented)
            type: str
            enum:
              - high
              - low
          "location":
            desc: Location (not currently implemented)
            type: str
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
          "notes":
            desc: Free-form notes string
            type: str
  YAML
  PROJECT_SCHEMA = YAML.safe_load(PROJECT_YAML_SCHEMA)
  class Project
    attr_reader :name, :tasks, :done, :notes, :location

    def initialize(options)
      @name = options["project"]

      @tasks = options["tasks"] || []
      @done = options["done"] || []

      @notes = options["notes"] if options["notes"]
      @location = options["location"] if options["location"]
      @status = options["status"] if options["status"]
    end

    def status
      return @status if @status

      if @tasks.count.positive?
        if @done.count.positive?
          "wip"
        else
          "planning"
        end
      else
        "idea"
      end
    end

    def to_s
      str = String.new
      str <<  "# #{@name}\n"
      str << "status: #{status}\n"
      str << "notes: #{notes}\n" unless @notes.nil?
      str << "location: #{location}\n" unless @location.nil?
      str << "tasks:\n" unless @tasks.empty?
      @tasks.each do |t|
        str << "- #{t}\n"
      end
      str << "done:\n" unless @done.empty?
      @done.each do |d|
        str << "- #{d}\n"
      end
      str
    end
    def to_h
      h = { "project" => @name }
      h["status"] = status unless status == "idea"
      h["notes"] = @notes unless @notes.nil?
      h["location"] = @location unless @location.nil?
      h["tasks"] = @tasks unless @tasks.empty?
      h["done"] = @done unless @done.empty?
      h
    end
  end

  class ProjectYAMLFile
    attr_reader :projects

    def initialize(path)
      @path = path
      # TODO: this won't GC, inline validation instead?
      @raw = YAML.load_file(path)
      validate_schema
      @projects = @raw.map { |proj| Project.new proj }
    end

    def validate_schema
      validator = Kwalify::Validator.new(Plansheet::PROJECT_SCHEMA)
      errors = validator.validate(@raw)
      # Check YAML validity
      if errors && !errors.empty?
        $stderr.write "Schema errors in #{l}\n"
        errors.each { |err| puts "- [#{err.path}] #{err.message}" }
        abort
      end
    end

    def sort!
      @projects.sort_by! do |project|
        Plansheet::PROJECT_STATUS_PRIORITY[project.status]
      end
    end

    def yaml_dump
      YAML.dump(@projects.map(&:to_h))
    end
  end
end
