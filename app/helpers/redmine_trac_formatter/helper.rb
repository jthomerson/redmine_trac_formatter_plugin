module RedmineTracFormatter
  module Helper
    unloadable

    def wikitoolbar_for(field_id)
      file = Engines::RailsExtensions::AssetHelpers.plugin_asset_path('redmine_trac_formatter', 'help', 'trac_syntax.html')
      help_link = l(:setting_text_formatting) + ': ' +
      link_to(l(:label_help), file,
              :onclick => "window.open(\"#{file}\", \"\", \"resizable=yes, location=no, width=300, height=640, menubar=no, status=no, scrollbars=yes\"); return false;")

      heads_for_wiki_formatter

      javascript_include_tag('jstoolbar/jstoolbar') +
        javascript_include_tag('trac', :plugin => 'redmine_trac_formatter') +
        javascript_include_tag("lang/trac-#{current_language}", :plugin => 'redmine_trac_formatter') +
        javascript_tag(<<-EOS + (Setting.plugin_redmine_trac_formatter[:trac_formatter_require_block].to_s == 'true' ? <<-EOT : ''))
          var editor = $('#{field_id}');
          var toolbar = new jsToolBar($('#{field_id}'));
          toolbar.setHelpLink('#{help_link}');
          toolbar.draw();
        EOS
          var toggler = document.createElement('div');
          toggler.className = 'jsToggler';
          var toggleButton = document.createElement('button');
          toggleButton.setAttribute('type', 'button');
          toggleButton.className = 'jsToggleButton jst_disabled';
          toggleButton.title = 'Trac';
          toggleButton.innerHTML = '<s>Trac</s>';
          toggler.appendChild(toggleButton);

          var toolbarElement = $A(editor.parentNode.parentNode.childNodes).find(function(x){ return x.className == 'jstElements'});
          toolbarElement.parentNode.insertBefore(toggler, toolbarElement);
          Element.hide(toolbarElement);

          handler = function(){
            Element.toggle(toolbarElement);

            var src = editor.value
            if (toggleButton.className.split(' ').include('jst_disabled')) {
              toggleButton.className = 'jsToggleButton jst_enabled';
              toggleButton.innerHTML = '<b>Trac</b>';
              if (!/^\\s*=begin/.test(src)) {
                src = "=begin\\n" + src;
                if (src[src.length - 1] != "\\n") src += "\\n";
                src += "=end\\n";
                editor.value = src;
              }
            } else {
              toggleButton.className = 'jsToggleButton jst_disabled';
              toggleButton.innerHTML = '<s>Trac</s>';
              editor.value = src.replace(/^\\s*=begin\\n/, '').replace(/=end\\n\\s*$/, '');
            }
          };
          Event.observe(toggleButton, 'click', handler);
        EOT
    end

    def initial_page_content(page)
      "= #{page.pretty_title} =\n"
    end

    def heads_for_wiki_formatter
      unless @heads_for_wiki_formatter_included
        content_for :header_tags do
          stylesheet_link_tag('jstoolbar.css') +
            stylesheet_link_tag('trac.css', :plugin => 'redmine_trac_formatter')
        end
        @heads_for_wiki_formatter_included = true
      end
    end
  end
end
