# frozen_string_literal: true

require "date"
module Plansheet
  # The Sheet class constructs a Markdown/LaTeX file for use with pdflatex
  class LaTeXSheet
    include LaTeXMixins
    def initialize(output_file, project_arr)
      projects_str = sheet_header
      projects_str << document do
        "\\thispagestyle{empty}\n\n\\section{Date: #{Date.today}}\n".concat(
          project_arr.map do |p|
            project_minipage(p)
          end.join
        )
      end
      puts "Writing to #{output_file}"
      File.write(output_file, projects_str)
    end

    def project_minipage(proj)
      minipage("6cm") do
        project_header(proj)&.concat(
          proj&.tasks&.map do |t|
            "#{checkbox_item sanitize_string(t)}#{HARD_NL}"
          end&.join("") || "" # empty string to catch nil
        )
      end
    end

    def project_header(proj)
      str = "#{sanitize_string(proj.namespace)}: #{sanitize_string(proj.name)}#{HARD_NL}"
      str << proj.status.to_s
      str << " - #{sanitize_string(proj.location)}" if proj.location
      str << " due: #{proj.due}" if proj.due
      str << " time: #{proj.time_estimate}" if proj.time_estimate
      str << HARD_NL
      str
    end
  end
end
