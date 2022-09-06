# frozen_string_literal: true

require "date"
module Plansheet
  module LaTeXMixins
    HARD_NL = " \\\\\n"
    SQUARE = "$\\square$"

    def vspace(space)
      "\\vspace{#{space}}\n"
    end

    def writein_line(space)
      "$\\underline{\\hspace{#{space}}}$"
    end

    def checkbox_item(str, line: nil)
      "#{SQUARE} #{str}#{" #{writein_line(line)}" if line}"
    end

    def vbox
      "\\vbox{\n#{yield}\n}\n"
    end

    %w[center document enumerate tabbing].each do |env|
      define_method(env.to_sym) do |&e|
        <<~ENV
          \\begin{#{env}}
          #{e.call}
          \\end{#{env}}
        ENV
      end
    end

    def itemize_tightlist
      <<~DOCUMENT
        \\begin{itemize}
        \\tightlist
        #{yield}
        \\end{itemize}
      DOCUMENT
    end

    def itemline(item, opt: nil)
      "\\item#{opt ? "[#{opt}]" : ""} #{item}\n"
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

    def sheet_header
      # LaTeX used to be generated by pandoc
      <<~FRONTMATTER
        \\PassOptionsToPackage{unicode}{hyperref}
        \\PassOptionsToPackage{hyphens}{url}
        \\documentclass[]{article}
        \\author{}
        \\date{#{Date.today}}
        \\usepackage{amsmath,amssymb}
        \\usepackage{lmodern}
        \\usepackage{iftex}
        \\usepackage[T1]{fontenc}
        \\usepackage[utf8]{inputenc}
        \\usepackage{textcomp}
        \\IfFileExists{upquote.sty}{\\usepackage{upquote}}{}
        \\IfFileExists{microtype.sty}{
          \\usepackage[]{microtype}
          \\UseMicrotypeSet[protrusion]{basicmath}
        }{}
        \\makeatletter
        \\@ifundefined{KOMAClassName}{
          \\IfFileExists{parskip.sty}{
            \\usepackage{parskip}
          }{
            \\setlength{\\parindent}{0pt}
            \\setlength{\\parskip}{6pt plus 2pt minus 1pt}}
        }{
          \\KOMAoptions{parskip=half}}
        \\makeatother
        \\usepackage{xcolor}
        \\IfFileExists{xurl.sty}{\\usepackage{xurl}}{}
        \\IfFileExists{bookmark.sty}{\\usepackage{bookmark}}{\\usepackage{hyperref}}
        \\hypersetup{
          hidelinks,
          pdfcreator={LaTeX via plansheet}}
        \\urlstyle{same}
        \\usepackage[margin=1.5cm]{geometry}
        \\setlength{\\emergencystretch}{3em}
        \\providecommand{\\tightlist}{
          \\setlength{\\itemsep}{0pt}\\setlength{\\parskip}{0pt}}
        \\setcounter{secnumdepth}{-\\maxdimen}
      FRONTMATTER
    end

    def config_file_sanity_check(options = {})
      options.each do |opt, type|
        unless @config[opt].is_a?(type) && !@config[opt]&.empty?
          abort "Need to specify #{opt} #{type.to_s.downcase} in your ~/.plansheet.yml config"
        end
      end
    end
  end
end