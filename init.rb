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

Redmine::Plugin.register :hrz_lib do
  name 'HRZ Lib'
  author 'Franz Apeltauer, Claude'
  description 'Redmine utility/library plugin. Provides common functions to other plugins and a REST API for CustomField creation/modification.'
  version '0.4.28'
  url '' #'https://github.com/franz-ap/hrz_lib'
  author_url ''
  requires_redmine version_or_higher: '6.1.0'
end

# Load library modules
require_relative 'lib/hrz_lib/issue_helper'
require_relative 'lib/hrz_lib/custom_field_helper'
require_relative 'lib/hrz_lib/hrz_tag_parser'
require_relative 'lib/hrz_lib/hrz_tag_functions'
require_relative 'lib/hrz_lib/hrz_auto_action'
