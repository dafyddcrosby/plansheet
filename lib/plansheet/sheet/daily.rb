# frozen_string_literal: false

require "date"
module Plansheet
  class DailyLaTeXSheet
    include Plansheet::LaTeXMixins
    def initialize(output_file, config)
      @config = config
      projects_str = sheet_header
      projects_str << document do
        sheet_body
      end

      puts "Writing to #{output_file}"
      File.write(output_file, projects_str)
    end

    def dateline
      <<~DATELINE
        \\thispagestyle{empty}

        Date \\(\\underline{\\hspace{4cm}}\\)

      DATELINE
    end

    INCOLUMN_SPACING = "7mm".freeze
    def sheet_body
      [
        dateline,
        vspace("1cm"),
        vbox do
          @config["top"].map do |section|
            minipage("8cm") do
              section_output(section)
            end
          end.join
        end,

        %w[left_bar right_bar].map do |col|
          minipage("8cm") do
            @config[col].map do |section|
              minipage("\\textwidth") do
                section_output(section)
              end
            end.join(vspace(INCOLUMN_SPACING))
          end
        end
      ].flatten.join
    end

    def section_output(section)
      case section["type"]
      when "checkboxes"
        checkboxes(section["items"])
      when "checkbox_and_lines"
        checkbox_and_lines(section["items"])
      when "multiline_checkbox_and_lines"
        multiline_checkbox_and_lines(section["items"])
      end
    end

    def checkboxes(items)
      items.map do |l|
        l.map do |i|
          checkbox_item i
        end.join(" ")
      end.join(HARD_NL)
    end

    def checkbox_and_lines(items)
      items.map do |i|
        checkbox_item(i, line: "4cm")
      end.join(HARD_NL)
    end

    def multiline_checkbox_and_lines(items)
      items.map do |q|
        "#{checkbox_item q} #{HARD_NL}#{writein_line("\\textwidth")}"
      end.join(HARD_NL)
    end
  end
end
