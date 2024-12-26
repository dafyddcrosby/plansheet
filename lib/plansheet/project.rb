# frozen_string_literal: true

require "yaml"
require "date"
require_relative "project/yaml"
require_relative "project/stringify"
require_relative "time"

module Plansheet
  module PlansheetArray
    # Needed for Project#time_estimate
    refine Array do
      def nil_if_empty
        count.zero? ? nil : self
      end
    end
  end
  using PlansheetArray

  PROJECT_STATUS_PRIORITY = {
    "wip" => 1,
    "ready" => 2,
    "blocked" => 3,
    "waiting" => 4,
    "planning" => 5,
    "idea" => 6,
    "paused" => 7,
    "dropped" => 8,
    "done" => 9
  }.freeze

  # Pre-compute the next days-of-week
  NEXT_DOW = 0.upto(6).to_h do |x|
    d = Date.today + x
    [d.strftime("%A"), d]
  end.freeze

  # The use of instance_variable_set/get probably seems a bit weird, but the
  # intent is to avoid object allocation on non-existent project properties, as
  # well as avoiding a bunch of copy-paste boilerplate when adding a new
  # property. I suspect I'm guilty of premature optimization here, but it's
  # easier to do this at the start than untangle that later (ie easier to
  # unwrap the loops if it's not needed.
  class Project
    include Comparable
    include Plansheet::TimeUtils

    TIME_EST_REGEX = /\((\d+\.?\d*[mMhH])\)$/
    TIME_EST_REGEX_NO_CAPTURE = /\(\d+\.?\d*[mMhH]\)$/

    PROJECT_PRIORITY = {
      "high" => 1,
      "medium" => 2,
      "low" => 3
    }.freeze

    COMPARISON_ORDER_SYMS = Plansheet::Pool::POOL_COMPARISON_ORDER.map { |x| :"compare_#{x}" }.freeze
    # NOTE: The order of these affects presentation!
    # namespace is derived from file name
    STRING_PROPERTIES = %w[priority status location notes time_estimate daily_time_roi weekly_time_roi yearly_time_roi
                           day_of_week frequency last_for lead_time].freeze
    DATE_PROPERTIES = %w[due defer paused_on dropped_on completed_on created_on starts_on last_done
                         last_reviewed].freeze
    ARRAY_PROPERTIES = %w[dependencies externals urls tasks setup_tasks cleanup_tasks done tags].freeze

    ALL_PROPERTIES = STRING_PROPERTIES + DATE_PROPERTIES + ARRAY_PROPERTIES

    attr_reader :name, :priority_val, :time_estimate_minutes, *ALL_PROPERTIES
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
      @priority_val = if @priority
                        PROJECT_PRIORITY[@priority]
                      else
                        PROJECT_PRIORITY["low"]
                      end

      # Remove stale defer dates
      remove_instance_variable("@defer") if @defer && (@defer < Date.today)

      # Add a created_on field if it doesn't exist
      instance_variable_set("@created_on", Date.today) unless @created_on

      # Handle nil-value tasks
      if @tasks
        @tasks.compact!
        remove_instance_variable("@tasks") if @tasks.empty?
      end

      # Generate time estimate from tasks if specified
      # Stomps time_estimate field
      if @tasks
        @time_estimate_minutes = @tasks&.grep(TIME_EST_REGEX_NO_CAPTURE)&.nil_if_empty&.map do |t| # rubocop:disable Style/SafeNavigationChainLength
          task_time_estimate(t)
        end&.sum
      elsif @time_estimate
        # No tasks with estimates, but there's an explicit time_estimate
        # Convert the field to minutes
        @time_estimate_minutes = parse_time_duration(@time_estimate)
      end
      if @time_estimate_minutes
        # Rewrite time_estimate field
        @time_estimate = build_time_duration(@time_estimate_minutes)

        yms = yearly_minutes_saved
        @time_roi_payoff = yms.to_f / @time_estimate_minutes if yms
      end

      if done?
        remove_instance_variable("@status") if @status
        unless recurring?
          @completed_on ||= Date.today
          remove_instance_variable("@time_estimate") if @time_estimate
          remove_instance_variable("@time_estimate_minutes") if @time_estimate
          remove_instance_variable("@time_roi_payoff") if @time_roi_payoff
        end
      elsif paused?
        @paused_on ||= Date.today
        remove_instance_variable("@status") if @status
      elsif dropped?
        @dropped_on ||= Date.today
        remove_instance_variable("@status") if @status
      end
    end

    def archive_month
      @completed_on&.strftime("%Y-%m") || Date.today.strftime("%Y-%m")
    end

    def yearly_minutes_saved
      if @daily_time_roi
        parse_time_duration(@daily_time_roi) * 365
      elsif @weekly_time_roi
        parse_time_duration(@weekly_time_roi) * 52
      elsif @yearly_time_roi
        parse_time_duration(@yearly_time_roi)
      end
    end

    def <=>(other)
      ret_val = 0
      COMPARISON_ORDER_SYMS.each do |method|
        ret_val = send(method, other)
        break if ret_val != 0
      end
      ret_val
    end

    def compare_priority(other)
      priority_val <=> other.priority_val
    end

    def time_roi_payoff
      @time_roi_payoff || 0
    end

    def compare_time_roi(other)
      other.time_roi_payoff <=> time_roi_payoff
    end

    def compare_status(other)
      PROJECT_STATUS_PRIORITY[status] <=> PROJECT_STATUS_PRIORITY[other.status]
    end

    # This seems silly at first glance, but it's to keep projects from flipping
    # around on each sort when they are equal in all other respects
    def compare_name(other)
      @name <=> other.name
    end

    def compare_completed_on(other)
      retval = 0
      retval += 1 if @completed_on
      retval -= 1 if other.completed_on
      retval = (other.completed_on <=> @completed_on) if retval.zero?
      retval
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

    def dependency_of?(other)
      other&.dependencies&.any? do |dep|
        @name&.downcase == dep.downcase
      end
    end

    def dependent_on?(other)
      @dependencies&.any? do |dep|
        other&.name&.downcase == dep.downcase
      end
    end

    def compare_dependency(other)
      # This approach might seem odd,
      # but it's to handle circular dependencies
      retval = 0
      retval -= 1 if dependency_of?(other)
      retval += 1 if dependent_on?(other)
      retval
    end

    # Projects that are dropped or done are considered "complete", insofar as
    # they are only kept around for later reference.
    def compare_completeness(other)
      retval = 0
      retval += 1 if dropped_or_done?
      retval -= 1 if other.dropped_or_done?
      retval
    end

    def status
      return @status if @status
      return "dropped" if @dropped_on
      return "paused" if @paused_on
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
      return "done" if @last_for && defer > Date.today
      return "done" if due && due > Date.today

      task_based_status
    end

    # Due date either explicit or recurring
    def due
      return @due if @due
      return recurring_due_date if recurring_due?

      nil
    end

    def recurring_due_date
      if @last_done
        return @last_done + parse_date_duration(@frequency) if @frequency

        if @day_of_week
          return Date.today + 7 if @last_done == Date.today
          return @last_done + 7 if @last_done < Date.today - 7

          return NEXT_DOW[@day_of_week]
        end
      end

      # Going to assume this is the first time, so due today
      Date.today
    end

    def defer
      return @defer if @defer
      return lead_time_deferral if @lead_time && due
      return last_for_deferral if @last_for

      nil
    end

    def last_for_deferral
      return @last_done + parse_date_duration(@last_for) if @last_done

      Date.today
    end

    def lead_time_deferral
      [(due - parse_date_duration(@lead_time)),
       Date.today].max
    end

    def recurring_due?
      !!(@frequency || @day_of_week)
    end

    def recurring?
      !!(@frequency || @day_of_week || @last_done || @last_for)
    end

    PROJECT_STATUS_PRIORITY.each_key do |stat|
      define_method(:"#{stat}?") do
        status == stat
      end
    end

    def dropped_or_done?
      dropped? || done?
    end

    def archivable?
      (!recurring? && @completed_on) || dropped?
    end

    def task_time_estimate(str)
      parse_time_duration(Regexp.last_match(1)) if str.match(TIME_EST_REGEX)
    end

    def to_h
      h = { "project" => @name, "namespace" => @namespace }
      ALL_PROPERTIES.each do |prop|
        h[prop] = instance_variable_get("@#{prop}") if instance_variable_defined?("@#{prop}")
      end
      h
    end
  end
end
