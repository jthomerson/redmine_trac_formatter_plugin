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
      t = @text.dup

      # Taken from http://trac.edgewall.org/wiki/WikiFormatting#Cheatsheet
      # Processed here in the order they appear in that chart to the extent possible

      # FONT STYLES
      # Wikipedia style:
      Oniguruma::ORegexp.new('(?<!!)\'\'\'\'\'(.+?)(?<!!)\'\'\'\'\'').gsub!(t, '<strong><em>\1</em></strong>')

      # Bold:
      Oniguruma::ORegexp.new('(?<![\'!])\'\'\'(.+?)(?<![\'!])\'\'\'').gsub!(t, '<strong>\1</strong>')
      Oniguruma::ORegexp.new('(?<!!)\*\*(.+?)(?<!!)\*\*').gsub!(t, '<strong>\1</strong>')

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

      ### PARAGRAPHS
      # TODO (two new lines is a paragraph break)

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

      ### PREFORMATTED TEXT
      # TODO:
      #{{{
      #multiple lines, ''no wiki''
      #      white space respected
      #}}}
      #<pre class="wiki">multiple lines, ''no wiki''
      #      white space respected
      #</pre>

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

      ### MISCELLANEOUS
      # TODO:
      #Line [[br]] break 
      #Line \\ break
      #----
      #<p>
      #Line <br /> break
      #Line <br /> break
      #</p>
      #<hr />

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
EOS
  x = <<EOS
This is a <strong>bold</strong> and <strong> bold </strong> <em>italic</em>
and <em>italic</em> <strong><em>test</em></strong> (<strong><em>!WikiCreole style</em></strong>)
but this !'''''is not bold or italics!'''''.
EOS

  f.test_parsing(x, t)
end
