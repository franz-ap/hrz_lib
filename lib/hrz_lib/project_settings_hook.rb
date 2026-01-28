#-------------------------------------------------------------------------------------------#
# Redmine utility/library plugin. Provides common functions to other plugins + REST API.    #
# Copyright (C) 2026 Franz Apeltauer                                                        #
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
# Purpose: Hook to integrate automation settings into project settings.

module HrzLib
  class ProjectSettingsHook < Redmine::Hook::ViewListener
    # Add the automation tab to project settings
    def project_settings_tabs(context = {})
      # Only show the tab if enabled via SettingsHelper
      return nil unless SettingsHelper.project_automation_tab_enabled?
      
      {
        name: 'automation',
        action: :show,
        partial: 'hrz_project_automation/show',
        label: :label_hrz_automation
      }
    end
  end
end
