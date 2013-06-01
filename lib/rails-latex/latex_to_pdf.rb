class LatexToPdf
  def self.config
    @config||={:command => 'pdflatex', :bibtex => false, :arguments => []}
  end

  # Converts a string of LaTeX +code+ into a binary string of PDF.
  #
  # pdflatex is used to convert the file and creates the directory +#{Rails.root}/tmp/rails-latex/+ to store intermediate
  # files.
  #
  # The config argument defaults to LatexToPdf.config but can be overridden using @latex_config.

  def self.generate_pdf(code, config)
    config=self.config.merge(config)
    dir=File.join(Rails.root,'tmp','rails-latex',"#{Process.pid}-#{Thread.current.hash}")
    input=File.join(dir,'input.tex')
    FileUtils.mkdir_p(dir)
    # use template, if any
    template = config[:template]
    if template.class == String
      FileUtils.cp_r(Dir["#{template}/*"],dir)
    end
    File.open(input,'wb') {|io| io.write(code) }
    Process.waitpid(
      fork do
        begin
          Dir.chdir dir
          STDOUT.reopen("input.log","a")
          STDERR.reopen(STDOUT)
          if config[:bibtex] == true
            # we need bibtex as well, so run pdflatex commands by hand
            system "pdflatex -halt-on-error -shell-escape input.tex"
            system 'bibtex input'
          end
          system "pdflatex -halt-on-error -shell-escape input.tex"
          system "pdflatex -halt-on-error -shell-escape input.tex"

        rescue
          File.open("input.log",'a') {|io|
            io.write("#{$!.message}:\n#{$!.backtrace.join("\n")}\n")
          }
        ensure
          Process.exit! 1
        end
      end)
    if File.exist?(pdf_file=input.sub(/\.tex$/,'.pdf'))
      FileUtils.mv(input.sub(/\.tex$/,'.log'),File.join(dir,'..','input.log'))
      result=File.read(pdf_file)
      #FileUtils.rm_rf(dir)
    else
      raise "pdflatex failed: See #{input.sub(/\.tex$/,'.log')} for details"
    end
    result
  end

  def self.input_latex(filename)
    filename = "#{Rails.root}/app/views/#{filename}"
    filename = "#{filename}.tex" unless File.extname(filename).present?
    file = File.open(filename, "r")
    input = file.read
    file.close
    input
  end
  # Escapes LaTex special characters in text so that they wont be interpreted as LaTex commands.
  #
  # This method will use RedCloth to do the escaping if available.
  def self.escape_latex(text)
    # :stopdoc:
    unless @latex_escaper
      if defined?(RedCloth::Formatters::LATEX)
        class << (@latex_escaper=RedCloth.new(''))
          include RedCloth::Formatters::LATEX
        end
      else
        class << (@latex_escaper=Object.new)
          ESCAPE_RE=/([{}_$&%#])|([\\^~|<>])/
          ESC_MAP={
            '\\' => 'backslash',
            '^' => 'asciicircum',
            '~' => 'asciitilde',
            '|' => 'bar',
            '<' => 'less',
            '>' => 'greater',
          }

          def latex_esc(text)   # :nodoc:
            text.gsub(ESCAPE_RE) {|m|
              if $1
                "\\#{m}"
              else
                "\\text#{ESC_MAP[m]}{}"
              end
            }
          end
        end
      end
      # :startdoc:
    end

    @latex_escaper.latex_esc(text.to_s).html_safe
  end
end
