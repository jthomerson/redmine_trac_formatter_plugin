# Redmine Trac Wiki Formatter
require 'redmine'

RAILS_DEFAULT_LOGGER.info 'Starting Trac formatter for Redmine'

Redmine::Plugin.register :redmine_trac_formatter do
  name 'Trac formatter'
  author 'Jeremy Thomerson (jthomerson)'
  description 'This provides Trac markup as a wiki format'
  version '0.0.1'
  url 'http://github.com/jthomerson/redmine_trac_formatter'
  author_url 'http://jeremythomerson.com'

  settings :default => {
    'trac_formatter_require_block' => true
  }, :partial => 'settings/trac_formatter_settings'

  wiki_format_provider 'Trac', RedmineTracFormatter::WikiFormatter, RedmineTracFormatter::Helper
end
