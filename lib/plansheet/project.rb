# frozen_string_literal: true

require "yaml"
require "date"
require_relative "project/yaml"
require_relative "project/stringify"

module Plansheet
  PROJECT_STATUS_PRIORITY = {
    "wip" => 1,
    "ready" => 2,
    "blocked" => 3,
    "waiting" => 4,
    "planning" => 5,
    "idea" => 6,
    "dropped" => 7,
    "done" => 8
  }.freeze

  PROJECT_PRIORITY = {
    "high" => 1,
    "medium" => 2,
    "low" => 3
  }.freeze

  def self.parse_date_duration(str)
    return Regexp.last_match(1).to_i if str.strip.match(/(\d+)[dD]/)
    return (Regexp.last_match(1).to_i * 7) if str.strip.match(/(\d+)[wW]/)

    raise "Can't parse time duration string #{str}"
  end

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
    # namespace is derived from file name
    STRING_PROPERTIES = %w[priority status location notes time_estimate frequency lead_time].freeze
    DATE_PROPERTIES = %w[due defer completed_on created_on starts_on last_done last_reviewed].freeze
    ARRAY_PROPERTIES = %w[dependencies externals urls tasks done tags].freeze

    ALL_PROPERTIES = STRING_PROPERTIES + DATE_PROPERTIES + ARRAY_PROPERTIES

    attr_reader :name, *ALL_PROPERTIES
    attr_accessor :namespace

    def initialize(options)
      @name = options["project"]
      @namespace = options["namespace"]

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
      return recurring_status if recurring?
      return task_based_status if @tasks || @done
      return "done" if @completed_on && @tasks.nil?

      "idea"
    end

    def task_based_status
      if @tasks&.count&.positive? && @done&.count&.positive?
        "wip"
      elsif @tasks&.count&.positive?
        "ready"
      elsif @done&.count&.positive?
        "done"
      else
        "idea"
      end
    end

    def recurring_status
      # add frequency to last_done
      if @last_done
        # This project has been done once before
        subsequent_recurring_status
      else
        # This recurring project is being done for the first time
        task_based_status
      end
    end

    def subsequent_recurring_status
      return "done" if @lead_time && defer > Date.today
      return "done" if due > Date.today

      task_based_status
    end

    def process_recurring
      # TODO: Tasks will be moved from done->tasks if recurring project is
      # starting again
    end

    # Due date either explicit or recurring
    def due
      return @due if @due
      return recurring_due_date if recurring?

      nil
    end

    def recurring_due_date
      if @last_done
        @last_done + Plansheet.parse_date_duration(@frequency)
      else
        Date.today
      end
    end

    def defer
      return @defer if @defer
      return lead_time_deferral if @lead_time && due

      nil
    end

    def lead_time_deferral
      [(due - Plansheet.parse_date_duration(@lead_time)),
       Date.today].max
    end

    def recurring?
      !@frequency.nil?
    end

    def dropped_or_done?
      status == "dropped" || status == "done"
    end

    def to_h
      h = { "project" => @name, "namespace" => @namespace }
      ALL_PROPERTIES.each do |prop|
        h[prop] = instance_variable_get("@#{prop}") if instance_variable_defined?("@#{prop}")
      end
      h.delete "priority" if h.key?("priority") && h["priority"] == "low"
      h.delete "status" if h.key?("status") && h["status"] == "idea"
      h
    end
  end
end
