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
      next_ending = ""
      tmp_buffer = ""

      text.each { |t|
        # look for things that end temp buffering blocks

        # PREFORMATTED TEXT (END MULTI-LINE BLOCK)
        # TODO: lookbehind for negation !
        if !parse_line && t =~ /^(.*?)\}\}\}(.*)$/
          parse_line = true # start normal parsing again
          t = $2 # only parse stuff after }}}
          formatted += "#{tmp_buffer}#{$1}</pre>" # add buffer and ending to formatted text
          tmp_buffer = '' # reset buffer
        end

        unless parse_line
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

        ### PREFORMATTED TEXT
        #{{{
        #multiple lines, ''no wiki''
        #      white space respected
        #}}}
        #<pre class="wiki">multiple lines, ''no wiki''
        #      white space respected
        #</pre>

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

        # Now do multi-line preformatted text parsing
        # TODO: lookbehind for negation !
        if t =~ /^(.*?)\{\{\{(.*)$/
          parse_line = false # don't parse lines until we find the end
          t = $1 # parse everything before {{{ just like you normally would
          tmp_buffer = "<pre class=\"wiki\">#{$2}\n" # store everything after in a temp buffer until }}} found
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

        ### TABLES
        # TODO:
        #||= Table Header =|| Cell ||
        #||||  (details below)  ||
        #<table class="wiki">
        #<tr><th> Table Header </th><td> Cell 
        #</td></tr><tr><td colspan="2" style="text-align: center">  (details below)  
        #</td></tr></table>
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

    def parse_one_line_markup(t)
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
      Oniguruma::ORegexp.new('(?<!!)\[\[[Bb][Rr]\]\]').gsub!(t, '<br />')
      #Line \\ break
      #Line <br /> break
      Oniguruma::ORegexp.new('(?<!!)\\\\').gsub!(t, '<br />')
      #----
      #<hr />
      t.gsub!(/^[\s]*----[\s]*$/, '<hr />')

      return t
    end

    def test_parsing(expected, wikitext)
      orig = @text
      @text = wikitext
      re = Oniguruma::ORegexp.new('\s+$')
      result = parse_trac_wiki
      @text = orig
      if re.gsub(result, '') == re.gsub(expected, '')
        puts "SUCCESS: #{wikitext.gsub(/[\r\n]/, "\\n")}"
      else
        puts "ERROR:\n"
        puts "Original:  #{wikitext}\n"
        puts "Expected:  #{expected}\n"
        puts "Formatted: #{result}"
      end
    end
  end
end


if __FILE__ == $0
  f = RedmineTracFormatter::WikiFormatter.new

  t = <<EOS
This is a '''bold''' and ** bold ** ''italic'' 
and //italic// '''''test''''' (**//!WikiCreole style//**)
but this !'''''is not bold or italics!'''''.
This is __underlined text__.

This is in a new paragraph.\\
And another hard-break preceded this line, which is followed by a horizontal rule
----
EOS
  x = <<EOS
<p>This is a <strong>bold</strong> and <strong> bold </strong> <em>italic</em>
and <em>italic</em> <strong><em>test</em></strong> (<strong><em>!WikiCreole style</em></strong>)
but this !'''''is not bold or italics!'''''.
This is <span class="underline">underlined text</span>.</p>
<p>This is in a new paragraph.<br />
And another hard-break preceded this line, which is followed by a horizontal rule
<hr />
</p>
EOS

  f.test_parsing(x, t)

  t = <<EOS
This is a line followed by a hard break[[BR]]
'''PRE BLOCK:'''{{{This is
   some preformatted text

 '''That does not get wiki-parsed'''
}}}'''But this''' ''does'' get parsed {{{And this '''doesn't'''}}}
And `this text is ''monospaced'' too`
EOS
  x = <<EOS
<p>This is a line followed by a hard break<br />
<strong>PRE BLOCK:</strong>
<pre class="wiki">This is
   some preformatted text

 '''That does not get wiki-parsed'''
</pre><strong>But this</strong> <em>does</em> get parsed <tt>And this '''doesn't'''</tt>
And <tt>this text is ''monospaced'' too</tt>
</p>
EOS

  f.test_parsing(x, t)

end
