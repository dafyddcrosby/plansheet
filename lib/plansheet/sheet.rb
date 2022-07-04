# frozen_string_literal: true

require "date"
module Plansheet
  # The Sheet class constructs a Markdown/LaTeX file for use with pandoc
  class Sheet
    def initialize(output_file, project_arr)
      projects_str = String.new
      projects_str << sheet_header

      project_arr.each do |p|
        projects_str << project_minipage(p)
      end
      puts "Writing to #{output_file}"
      File.write(output_file, projects_str)
    end

    def sheet_header
      <<~FRONTMATTER
        ---
        geometry: margin=1.5cm
        ---
        \\thispagestyle{empty}

        # Date: #{Date.today}
      FRONTMATTER
    end

    def project_minipage(proj)
      str = String.new
      str << "\\begin{minipage}{6cm}\n"
      str << project_header(proj)
      proj&.tasks&.each do |t|
        str << "$\\square$ #{sanitize_string(t)} \\\\\n"
      end
      str << "\\end{minipage}\n"
      str
    end

    def sanitize_string(str)
      str.gsub("_", '\_')
    end

    def project_header(proj)
      str = String.new
      str << "#{proj.namespace}: #{proj.name}\\\\\n"
      str << proj.status.to_s
      str << " - #{proj.location}" if proj.location
      str << " due: #{proj.due}" if proj.due
      str << " time: #{proj.time_estimate}" if proj.time_estimate
      str << " \\\\\n"
      str
    end
  end
end
