# frozen_string_literal: false

require "date"
module Plansheet
  class WeeklyLaTeXSheet
    include LaTeXMixins
    include TimeUtils
    MINIPAGE_SIZE = "6cm".freeze
    def initialize(output_file, projects, config)
      @config = config || {}
      config_file_sanity_check({
                                 "namespaces" => Hash,
                                 "tags" => Hash
                               })

      @external_commits = projects.select(&:externals) || []
      @projects = projects # TODO: remove finished?
      str = sheet_header
      str << document do
        [
          week_line,
          [
            event_writeins,
            past_due,
            upcoming_due
          ].compact.join,
          # Since the following are a lot more volatile in minipage length,
          # sort by newline so more fits on the page
          [
            external_commits,
            works_in_progress,
            tag_minipages,
            namespace_minipages,
            recurring_defer
          ].flatten.compact.sort_by { |x| x.count("\n") }.join
        ].flatten.join
      end
      puts "Writing to #{output_file}"
      File.write(output_file, str)
    end

    def namespace_minipages
      @config["namespaces"].map do |namespace, limit|
        projects = @projects.select { |x| x.namespace == namespace }
        project_minipage namespace, projects_in_time(projects, limit)
      end&.join
    end

    def tag_minipages
      @config["tags"].map do |tag, limit|
        projects = @projects.select { |x| x&.tags&.any?(tag) }
        project_minipage pretty_tag_name(tag), projects_in_time(projects, limit)
      end&.join
    end

    def works_in_progress
      projects = @projects.select(&:wip?)
      project_minipage "Works in progress", projects if projects
    end

    def past_due
      projects = @projects.select { |x| x.due ? x.due < Date.today : false }
      project_minipage "Past due", projects if projects
    end

    def recurring_defer
      projects = @projects.select { |x| x.last_for ? x.last_for_deferral < Date.today + 8 : false }
      project_minipage "Recurring defer", projects if projects
    end

    def upcoming_due
      projects = @projects.select { |x| x.due ? (x.due >= Date.today && x.due < Date.today + 8) : false }
      project_minipage "Upcoming due", projects if projects
    end

    def external_commits
      project_minipage("Externals", @external_commits) unless @external_commits&.empty?
    end

    def event_writeins
      minipage(MINIPAGE_SIZE) do
        "Events:\n#{
          itemize_tightlist do
            7.times.map do |n|
              itemline(
                writein_line("4cm"),
                opt: (Date.today + n).strftime("%a %m-%d")
              )
            end.join.concat("\n")
          end
        }"
      end
    end

    def pretty_tag_name(tag)
      tag.capitalize.gsub("_", " ")
    end

    def project_minipage(thing, projects = [])
      unless projects&.empty?
        minipage(MINIPAGE_SIZE) do
          "#{thing}:
        #{itemize_tightlist do
            projects&.map do |x|
              itemline("#{x.name} #{x&.time_estimate}", opt: SQUARE)
            end&.join("\n")
          end
        }"
        end
      end
    end

    DEFAULT_PROJECT_TIME_ESTIMATE_MIN = 120
    def projects_in_time(projects, time)
      projects ||= []
      t = parse_time_duration(time)
      p = []
      projects.each do |proj|
        e = proj&.time_estimate ? parse_time_duration(proj.time_estimate) : DEFAULT_PROJECT_TIME_ESTIMATE_MIN
        if e <= t
          p.append proj
          t -= e
        end
      end
      p
    end

    def week_line
      "For the next week: #{Date.today} - #{Date.today + 7}\n\n"
    end
  end
end
