# frozen_string_literal: true

require "date"
module Plansheet
  # The Sheet class constructs a Markdown/LaTeX file for use with pandoc
  class Sheet
    def initialize(output_file, project_arr)
      sorted_arr = project_arr.sort!

      projects_str = String.new
      projects_str << sheet_header

      sorted_arr.first(60).each do |p|
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
      str << "\\begin{minipage}{4.5cm}\n"
      str << project_header(proj)
      proj.tasks.each do |t|
        str << "$\\square$ #{t} \\\\\n"
      end
      str << "\\end{minipage}\n"
      str
    end

    def project_header(proj)
      str = String.new
      str << "#{proj.name} - #{proj.status}"
      str << " - #{proj.location}" if proj.location
      str << " \\\\\n"
      str
    end
  end
end
