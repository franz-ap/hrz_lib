#-------------------------------------------------------------------------------------------#
# Redmine utility/library plugin. Provides common functions to other plugins + REST API.    #
# Copyright (C) 2025 Franz Apeltauer                                                        #
#                                                                                           #
# This program is free software: you can redistribute it and/or modify it under the terms   #
# of the GNU Affero General Public License as published by the Free Software Foundation,    #
# either version 3 of the License, or (at your option) any later version.                   #
#                                                                                           #
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; #
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. #
# See the GNU Affero General Public License for more details.                               #
#                                                                                           #
# You should have received a copy of the GNU Affero General Public License                  #
# along with this program.  If not, see <https://www.gnu.org/licenses/>.                    #
#-------------------------------------------------------------------------------------eohdr-#
# Purpose: Plugin registration file for the Redmine utility/library plugin.

require 'redmine'

t_start_hrz_lib = Time.now
Redmine::Plugin.register :hrz_lib do
  name        'HRZ Lib'
  author      'Franz Apeltauer, Claude'
  description 'Redmine utility/library plugin. Provides common functions to other plugins and a REST API for CustomField creation/modification.'
  version     '0.6.46'
  url         'https://github.com/franz-ap/hrz_lib'
  author_url  ''
  requires_redmine version_or_higher: '6.1.0'

  # Plugin settings configuration
  settings default: {
    'debug_user_id'                 => '',
    'q_verbose_log'                 => false,
    'q_verbose_issue_helper'        => false,
    'q_verbose_custom_field_helper' => false,
    'q_verbose_parser'              => false,
    'q_verbose_tag_functions'       => false,
    'q_verbose_http_requests'       => false,
    'q_redirect_emails'             => false
  }, partial: 'settings/hrz_lib_settings'

  # Add menu item for automation settings
  menu :admin_menu, :hrz_automation,
       { controller: 'hrz_automation_settings', action: 'index' },
       caption: :label_hrz_automation,
       html: { class: 'icon icon-workflows' }
end

# Load library modules
require_relative 'lib/hrz_lib/issue_helper'
require_relative 'lib/hrz_lib/custom_field_helper'
require_relative 'lib/hrz_lib/hrz_tag_parser'
require_relative 'lib/hrz_lib/hrz_tag_functions'
require_relative 'lib/hrz_lib/hrz_auto_action'
require_relative 'lib/hrz_lib/hrz_http'

# Benchmark
puts "Plugin 'HRZ Lib' loaded in #{((Time.now - t_start_hrz_lib) * 1000).round(2)} ms"
