#-------------------------------------------------------------------------------------------#
# Redmine utility/library plugin.                                                           #
# Provides common functions to other plugins,                                               #
#          a REST API for CustomField creation/modification,                                #
#          a transport utility for developers/admins.                                       #
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

Redmine::Plugin.register :hrz_lib do
  name 'HRZ Lib'
  author 'Franz Apeltauer, Claude'
  description 'Redmine utility/library plugin. Provides common functions to other plugins, a REST API for CustomField creation/modification, a transport utility for developers/admins.'
  version '0.2.1'
  url '' #'https://github.com/franz-ap/hrz_lib'
  author_url ''
  requires_redmine version_or_higher: '6.1.0'

  # Add settings with default values
  settings default: {
    'transport_target_url' => ''
  }, partial: 'settings/hrz_lib_settings'

  # Add menu item in admin menu
  menu :admin_menu, :hrz_transports,
       { controller: 'hrz_transports', action: 'index' },
       caption: :label_hrz_transports,
       html: { class: 'icon icon-package' }
end

# Load library modules
require_relative 'lib/hrz_lib/issue_helper'
require_relative 'lib/hrz_lib/custom_field_helper'
require_relative 'lib/hrz_lib/transport_helper'
