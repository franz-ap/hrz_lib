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
# Purpose: Patch ProjectsHelper to add automation tab to project settings.

module HrzLib
  module ProjectsHelperPatch
    # Extends project_settings_tabs to add the Automation tab.
    # @return [Array<Hash>] Array of tab definitions
    def project_settings_tabs
      tabs = super

      # Only add tab if enabled (pass @project from the controller context)
      if HrzLib::SettingsHelper.project_automation_tab_enabled?(@project)
        tabs << {
          name: 'automation',
          action: :edit_project,
          partial: 'hrz_project_automation/show',
          label: :label_hrz_automation
        }
      end

      tabs
    end
  end
end

# Apply the patch using prepend (Rails 6+ recommended approach)
Rails.application.config.after_initialize do
  ProjectsHelper.prepend(HrzLib::ProjectsHelperPatch)
end
