# frozen_string_literal: true

require "date"
module Plansheet
  module LaTeXMixins
    HARD_NL = " \\\\\n"

    def vspace(space)
      "\\vspace{#{space}}\n"
    end

    def writein_line(space)
      "$\\underline{\\hspace{#{space}}}$"
    end

    def checkbox_item(str)
      "$\\square$ #{str}"
    end

    def vbox
      <<~VBOX
        \\vbox{
        #{yield}
        }
      VBOX
    end

    def document
      <<~DOCUMENT
        \\begin{document}
        #{yield}
        \\end{document}
      DOCUMENT
    end

    def minipage(size)
      <<~MINIPAGE
        \\begin{minipage}{#{size}}
        #{yield}
        \\end{minipage}
      MINIPAGE
    end

    def sanitize_string(str)
      str.gsub("_", '\_')
    end
  end
end
