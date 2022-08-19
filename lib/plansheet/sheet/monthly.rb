# frozen_string_literal: false

require "date"
module Plansheet
  class MonthlyLaTeXSheet
    include LaTeXMixins
    def initialize(output_file, config)
      @config = config || {}
      config_file_sanity_check({
                                 "highlevel_items" => Array,
                                 "tags" => Hash
                               })

      str = sheet_header
      str << document do
        [
          month_line,
          highlevel_items,
          center do
            [
              events_minipage,
              tags_minipages
            ].join
          end,
          monthly_calendar_grid
        ].join
      end
      puts "Writing to #{output_file}"
      File.write(output_file, str)
    end

    def highlevel_items
      itemize_tightlist do
        @config["highlevel_items"].map do |i|
          itemline("#{i} #{writein_line("5cm")}", opt: SQUARE)
        end.join.concat("\n")
      end
    end

    def tags_minipages
      minipage("6.5cm") do
        @config["tags"].map { |k, v| tag_minipage k, v }.join
      end.concat("\n")
    end

    def events_minipage
      minipage("8cm") do
        "Events:\n#{
          itemize_tightlist do
            30.times.map do |n|
              itemline(
                writein_line("6cm"),
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

    def tag_minipage(tag, items = 10)
      "#{pretty_tag_name tag}:\n".concat(
        itemize_tightlist do
          items.times.map do
            itemline(writein_line("6cm"), opt: SQUARE)
          end.join
        end
      )
    end

    def month_line
      "For the next month: #{Date.today} - #{Date.today + 30}\n\n"
    end

    def monthly_calendar_grid
      <<~GRID
        \\begin{tabular}{|#{7.times.map { "p{2cm}" }.join("|")}|}
        \\hline
      GRID
        .concat(
          %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].join(" & ").concat(HARD_NL)
        ).concat(
          5.times.map do |n|
            calendar_grid_line n
          end.join(HARD_NL).concat(HARD_NL)
        ).concat(
          <<~GRID
            \\hline
            \\end{tabular}
          GRID
        )
    end

    private

    def calendar_grid_line(week_multiplier = 0)
      "\\hline\n#{
        7.times.map do |n|
          (Date.today - Date.today.wday + (n + (week_multiplier * 7))).strftime("%d")
        end.join(" & ")
      } #{
        vspace("5mm")
      }"
    end
  end
end
