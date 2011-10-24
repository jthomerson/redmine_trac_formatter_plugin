require 'rubygems'
require 'oniguruma'

module RedmineTracFormatter
  class WikiFormatter

    attr_accessor :text

    # Create the object
    def initialize(text = "")
      @text = text
    end

    def to_html(&block)
      return "" unless /\S/m =~ @text

      return parse_trac_wiki

    rescue RuntimeError => e
      return "<pre>#{e.message}</pre>"
    end

    def parse_trac_wiki
      text = @text.dup

      ### PARAGRAPHS
      # TODO: verify that this behavior is valid - opening and closing entire wikitext with p tags
      text = "<p>#{text}</p>"
      text.gsub!(/\r\n/, "\n") # remove any CRLF with just LF
      text.gsub!(/\r/, "\n")   # now replace CR by itself with LF

      formatted = ""
      parse_line = true
      block_ending = ""
      next_ending = ""
      tmp_buffer = ""

      text.each { |t|
        # look for things that end temp buffering blocks

        # PREFORMATTED TEXT (END MULTI-LINE BLOCK)
        # TODO: lookbehind for negation !
        if !parse_line && block_ending == "}}}" && t =~ /^(.*?)\}\}\}(.*)$/
          parse_line = true # start normal parsing again
          block_ending = ""
          t = $2 # only parse stuff after }}}
          formatted += "#{tmp_buffer}#{$1}</pre>" # add buffer and ending to formatted text
          tmp_buffer = '' # reset buffer
        end

        # TABLES LINE CONTINUES
        if !parse_line && block_ending == "||"
          # we were parsing a table
          if t =~ /^\|\|.*/
            # another table line
            tmp_buffer += parse_table_line(t)
            next
          else
            formatted += tmp_buffer + "</tbody>\n</table>\n"
            parse_line = true
            tmp_buffer = ""
            block_ending = ""
          end
        end

        if !parse_line
          tmp_buffer += "#{t}"
          next
        end

        # trim string to make white-space only line an empty line and use our
        # own newlines as needed
        t.strip!

        ### PARAGRAPHS (empty line becomes end of paragraph and start of new paragraph)
        # TODO: duplicate new lines should probably not open and close empty paragraphs
        if "" == t
          formatted.chomp!
          formatted += "</p>\n<p>"
          next
        end

        # First parse preformatted text appearing all inline
        ### MONOSPACE
        # `this text`
        # <tt>this text</tt>
        # {{{this text}}}
        # <tt>this text</tt>
        if t =~ /(.*?)([^!]?)`(.+?[^!]?)`(.*)/ || t =~ /(.*?)([^!]?)\{\{\{(.+?[^!]?)\}\}\}(.*)/ 
          formatted += parse_one_line_markup("#{$1}#{$2}")
          formatted += "<tt>#{$3}</tt>"
          formatted += parse_one_line_markup($4) + "\n"
          next
        end

        ### PREFORMATTED TEXT
        #{{{
        #multiple lines, ''no wiki''
        #      white space respected
        #}}}
        #<pre class="wiki">multiple lines, ''no wiki''
        #      white space respected
        #</pre>

        # Now do multi-line preformatted text parsing
        # TODO: lookbehind for negation !
        if t =~ /^(.*?)\{\{\{(.*)$/
          parse_line = false   # don't parse lines until we find the end
          block_ending = "}}}" # so our code above knows we're buffering preformatted text
          t = $1 # parse everything before {{{ just like you normally would
          tmp_buffer = "<pre class=\"wiki\">#{$2}\n" # store everything after in a temp buffer until }}} found
        end

        ### TABLES
        #||= Table Header =|| Cell ||
        #||||  (details below)  ||
        #<table class="wiki">
        #<tr><th> Table Header </th><td> Cell 
        #</td></tr><tr><td colspan="2" style="text-align: center">  (details below)  
        #</td></tr></table>
        #
        if t =~ /^\|\|(.*)\|\|\s*$/
          # TODO: allow for trailing backslash to continue tr on next line
          parse_line = false   # don't parse lines until we find the end
          block_ending = "||"  # so our code above knows we're buffering a table
          t = "" # don't parse anything else on this line
          tmp_buffer = "<table class=\"wiki\">\n<tbody>\n" # start the table 
          tmp_buffer += parse_table_line($1)
        end

        t = parse_one_line_markup(t)

        ### LISTS
        # TODO:
        #* bullets list
        #  on multiple lines
        #  1. nested list
        #    a. different numbering 
        #       styles
        # 
        #<ul><li>bullets list
        #on multiple lines
        #<ol><li>nested list
        #<ol class="loweralpha"><li>different numbering
        #styles
        #</li></ol></li></ol></li></ul>

        ### DEFINITION LISTS
        # TODO:
        # term:: definition on
        #        multiple lines
        # <dl><dt>(term)</dt><dd>definition on
        #        multiple lines</dd></dl>

        ### BLOCKQUOTES
        # TODO:
        #  if there's some leading
        #  space the text is quoted
        #<blockquote>
        #<p>
        #if there's some leading
        #space the text is quoted
        #</p>
        #</blockquote>

        ### DISCUSSION CITATIONS
        # TODO:
        #>> ... (I said)
        #> (he replied)
        #<blockquote class="citation">
        #<blockquote class="citation">
        #<p>
        #... (I said)
        #</p>
        #</blockquote>
        #<p>
        #(he replied)
        #</p>
        #</blockquote>
        #

        ### LINKS
        # TODO: (do we need to do them or does it already handle them?)
        # ALSO: TRACLINKS
        #
        ### SETTING ANCHORS
        # TODO:
        #[=#point1 (1)] First...
        #<span class="wikianchor" id="point1">(1)</span> First...
        #see [#point1 (1)]
        #see <a class="wiki" href="/wiki/WikiFormatting#point1">(1)</a> 
        #

        ### IMAGES
        # TODO:
        #[[Image(link)]]	
        #<a style="padding:0; border:none" href="/chrome/site/../common/trac_logo_mini.png"><img src="/chrome/site/../common/trac_logo_mini.png" alt="trac_logo_mini.png" title="trac_logo_mini.png" /></a> 
        #

        ### MACROS
        # TODO: probably won't do this unless redmine has it built in
        #[[MacroList(*)]] becomes a list of all available macros
        #[[Image?]] becomes help for the Image macro
        #

        ### PROCESSORS AND CODE FORMATTING
        # TODO:
        #{{{
        ##!div style="font-size: 80%"
        #Code highlighting:
        #  {{{#!python
        #  hello = lambda: "world"
        #  }}}
        #}}}
        #<div style="font-size: 80%" class="wikipage"><p>
        #Code highlighting:
        #</p>
        #<div class="code"><pre>hello <span class="o">=</span> <span class="k">lambda</span><span class="p">:</span> <span class="s">"world"</span>
        #</pre></div></div>
        #

        ### COMMENTS
        # TODO: (the following gets removed completely
        #{{{#!comment
        #Note to Editors: ...
        #}}}
        #

        formatted += "#{t}\n"
      } # end of each block over string lines

      return formatted
    end

    def parse_table_line(t)
      t = t.chomp.gsub(/^\s*\|\|(.*)\|\|\s*$/, '\1')
      ret = ""
      t.each("||") { |cell|
        cell.gsub!(/\|\|\s*$/, '')
        boundary = "td"
        style = ""
        contents = cell
        if cell =~ /^=(.*)=$/
          boundary = "th"
          contents = $1
        end
        if contents =~ /^\S/
          style=" style='text-align: left'"
        elsif contents =~ /.*\S$/
          style=" style='text-align: right'"
        end
        contents = parse_one_line_markup(contents)
        ret += "<#{boundary}#{style}>#{contents}</#{boundary}>"
      }
      return "<tr>#{ret}</tr>\n"
    end

    def parse_one_line_markup(t)
      # LINKS
      # we don't directly create links but instead double the brackets so Redmine can parse them for us
      # TODO: this isn't working....  Redmine must parse links separately or before this.  need to investigate
      # Oniguruma::ORegexp.new('(?<!!)\[(.+?)(?<!!)\]').gsub!(t, '[[\1]]')

      # FONT STYLES
      # Wikipedia style:
      Oniguruma::ORegexp.new('(?<!!)\'\'\'\'\'(.+?)(?<!!)\'\'\'\'\'').gsub!(t, '<strong><em>\1</em></strong>')

      # Bold:
      Oniguruma::ORegexp.new('(?<![\'!])\'\'\'(.+?)(?<![\'!])\'\'\'').gsub!(t, '<strong>\1</strong>')
      Oniguruma::ORegexp.new('(?<!!)\*\*(.+?)(?<!!)\*\*').gsub!(t, '<strong>\1</strong>')

      # Underline:
      Oniguruma::ORegexp.new('(?<!!)\_\_(.+?)(?<!!)\_\_').gsub!(t, '<span class="underline">\1</span>')

      # Italics:
      Oniguruma::ORegexp.new('(?<![\'!])\'\'(.+?)(?<![\'!])\'\'').gsub!(t, '<em>\1</em>')
      Oniguruma::ORegexp.new('(?<!!)//(.+?)(?<!!)//').gsub!(t, '<em>\1</em>')
      # TODO: need monospacing with markup within monospace markers ignored

      # HEADINGS
      # all headings (TODO: see if we can do this better using the scan method
      #                     and count number of equals signs to determine heading num)
      Oniguruma::ORegexp.new('(?<!!)===== (.+?)(?<!!) =====').gsub!(t, '<h5>\1</h5>')
      Oniguruma::ORegexp.new('(?<!!)==== (.+?)(?<!!) ====').gsub!(t, '<h4>\1</h4>')
      Oniguruma::ORegexp.new('(?<!!)=== (.+?)(?<!!) ===').gsub!(t, '<h3>\1</h3>')
      Oniguruma::ORegexp.new('(?<!!)== (.+?)(?<!!) ==').gsub!(t, '<h2>\1</h2>')
      Oniguruma::ORegexp.new('(?<!!)= (.+?)(?<!!) =').gsub!(t, '<h1>\1</h1>')

      ### MISCELLANEOUS
      #Line [[br]] break 
      #Line <br /> break
      t.gsub!(/\[\[[Bb][Rr]\]\]/, '<br />')
      # Oniguruma::ORegexp.new('(?<!!)\[\[[Bb][Rr]\]\]').gsub!(t, '<br />')
      #Line \\ break
      #Line <br /> break
      t.gsub!(/\\\\/, '<br />')
      # Oniguruma::ORegexp.new('(?<!!)\\\\\\').gsub!(t, '<br />')
      #----
      #<hr />
      t.gsub!(/^[\s]*----[\s]*$/, '<hr />')

      return t
    end
  end
end


if __FILE__ == $0
  f = RedmineTracFormatter::WikiFormatter.new

  infile = ARGV[0]
  expfile = ARGV[1]

  file = File.open("#{infile}", "rb")
  input = file.read
  f.text = input
  output = f.parse_trac_wiki

  outfile = '/tmp/test.output'
  File.open(outfile, 'w') {|f| f.write(output) }

  exec "diff #{expfile} #{outfile}" 
end
