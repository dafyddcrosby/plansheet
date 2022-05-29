# frozen_string_literal: true

require "date"
module Plansheet
  class Sheet
    def initialize(output_file, project_arr)
      sorted_arr = project_arr.sort_by do |p|
        Plansheet::PROJECT_STATUS_PRIORITY[p.status]
      end

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
      str << "#{proj.name} - #{proj.status} \\\\\n"
      proj.tasks.each do |t|
        str << "$\\square$ #{t} \\\\\n"
      end
      str << "\\end{minipage}\n"
      str
    end
  end
end
