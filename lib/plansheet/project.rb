# frozen_string_literal: true

require "yaml"
require "date"

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

  PROJECT_PRIORITY = {
    "high" => 1,
    "medium" => 2,
    "low" => 3
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
              - ready # project is fully scoped, ready to go
              - blocked # project is blocked, but otherwise ready/wip
              - planning # project in planning phase
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
          "due":
            desc: Due date of the task
            type: date
          "defer":
            desc: Defer task until this day
            type: date
          "last_reviewed":
            desc: When the project was last reviewed (WIP)
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

  # The use of instance_variable_set/get probably seems a bit weird, but the
  # intent is to avoid object allocation on non-existent project properties, as
  # well as avoiding a bunch of copy-paste boilerplate when adding a new
  # property. I suspect I'm guilty of premature optimization here, but it's
  # easier to do this at the start than untangle that later (ie easier to
  # unwrap the loops if it's not needed.
  class Project
    include Comparable

    DEFAULT_COMPARISON_ORDER = %w[
      completeness
      dependency
      priority
      defer
      due
      status
    ].map { |x| "compare_#{x}".to_sym }.freeze
    # NOTE: The order of these affects presentation!
    STRING_PROPERTIES = %w[priority status location notes].freeze
    DATE_PROPERTIES = %w[due defer last_reviewed].freeze
    ARRAY_PROPERTIES = %w[dependencies externals urls tasks done tags].freeze

    ALL_PROPERTIES = STRING_PROPERTIES + DATE_PROPERTIES + ARRAY_PROPERTIES

    attr_reader :name, *ALL_PROPERTIES

    def initialize(options)
      @name = options["project"]

      ALL_PROPERTIES.each do |o|
        instance_variable_set("@#{o}", options[o]) if options[o]
      end

      # The "priority" concept feels flawed - it requires *me* to figure out
      # the priority, as opposed to the program understanding the project in
      # relation to other tasks. If I truly understood the priority of all the
      # projects, I wouldn't need a todo list program. The point is to remove
      # the need for willpower/executive function/coffee. The long-term value
      # of this field will diminish as I add more project properties that can
      # automatically hone in on the most important items based on due
      # date/external commits/penalties for project failure, etc
      #
      # Assume all projects are low priority unless stated otherwise.
      @priority ||= "low"
    end

    def <=>(other)
      ret_val = 0
      DEFAULT_COMPARISON_ORDER.each do |method|
        ret_val = send(method, other)
        break if ret_val != 0
      end
      ret_val
    end

    def compare_priority(other)
      PROJECT_PRIORITY[@priority] <=> PROJECT_PRIORITY[other.priority]
    end

    def compare_status(other)
      PROJECT_STATUS_PRIORITY[status] <=> PROJECT_STATUS_PRIORITY[other.status]
    end

    def compare_due(other)
      # -1 is receiving object being older

      # Handle nil
      if @due.nil?
        return 0 if other.due.nil?

        return 1
      elsif other.due.nil?
        return -1
      end

      @due <=> other.due
    end

    def compare_defer(other)
      receiver = @defer.nil? || @defer < Date.today ? Date.today : @defer
      comparison = other.defer.nil? || other.defer < Date.today ? Date.today : other.defer
      receiver <=> comparison
    end

    def compare_dependency(other)
      return 0 if @dependencies.nil? && other.dependencies.nil?

      if @dependencies.nil?
        return -1 if other.dependencies.any? do |dep|
          @name.downcase == dep.downcase
        end
      elsif @dependencies.any? do |dep|
              other.name.downcase == dep.downcase
            end
        return 1
      end
      0
    end

    # Projects that are dropped or done are considered "complete", insofar as
    # they are only kept around for later reference.
    def compare_completeness(other)
      return 0 if dropped_or_done? && other.dropped_or_done?
      return 0 if !dropped_or_done? && !other.dropped_or_done?

      dropped_or_done? ? 1 : -1
    end

    def status
      return @status if @status

      if @tasks&.count&.positive?
        if @done&.count&.positive?
          "wip"
        else
          "planning"
        end
      else
        "idea"
      end
    end

    def dropped_or_done?
      status == "dropped" || status == "done"
    end

    def to_s
      str = String.new
      str << "# #{@name}\n"
      STRING_PROPERTIES.each do |o|
        str << stringify_string_property(o)
      end
      DATE_PROPERTIES.each do |o|
        str << stringify_string_property(o)
      end
      ARRAY_PROPERTIES.each do |o|
        str << stringify_array_property(o)
      end
      str
    end

    def stringify_string_property(prop)
      if instance_variable_defined? "@#{prop}"
        "#{prop}: #{instance_variable_get("@#{prop}")}\n"
      else
        ""
      end
    end

    def stringify_date_property(prop)
      if instance_variable_defined? "@#{prop}"
        "#{prop}: #{instance_variable_get("@#{prop}")}\n"
      else
        ""
      end
    end

    def stringify_array_property(prop)
      str = String.new
      if instance_variable_defined? "@#{prop}"
        str << "#{prop}:\n"
        instance_variable_get("@#{prop}").each do |t|
          str << "- #{t}\n"
        end
      end
      str
    end

    def to_h
      h = { "project" => @name }
      ALL_PROPERTIES.each do |prop|
        h[prop] = instance_variable_get("@#{prop}") if instance_variable_defined?("@#{prop}")
      end
      h.delete "priority" if h.key?("priority") && h["priority"] == "low"
      h.delete "status" if h.key?("status") && h["status"] == "idea"
      h
    end
  end

  class ProjectYAMLFile
    attr_reader :projects

    def initialize(path)
      @path = path
      # TODO: this won't GC, inline validation instead?

      # Handle pre-Ruby 3.1 psych versions (this is brittle)
      @raw = if Psych::VERSION.split(".")[0].to_i >= 4
               YAML.load_file(path, permitted_classes: [Date])
             else
               YAML.load_file(path)
             end

      validate_schema
      @projects = @raw.map { |proj| Project.new proj }
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

    def yaml_dump
      YAML.dump(@projects.map(&:to_h))
    end
  end
end
