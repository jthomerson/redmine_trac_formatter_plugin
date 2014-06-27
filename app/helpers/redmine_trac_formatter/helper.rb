module RedmineTracFormatter
  module Helper
    unloadable

    def wikitoolbar_for(field_id)
        heads_for_wiki_formatter
    end

    def initial_page_content(page)
      "= #{page.pretty_title} =\n"
    end

    def heads_for_wiki_formatter
          unless @heads_for_wiki_formatter_included
            content_for :header_tags do
            end
            @heads_for_wiki_formatter_included = true
          end
    end
  end
end
