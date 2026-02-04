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
# Purpose: Extend Redmine's Project model with automation action associations.

module HrzLib
  module ProjectPatch
    def self.included(base)
      base.class_eval do
        has_many :project_actions,
                 class_name: 'HrzlibAutProjectAction',
                 foreign_key: 'project_id',
                 dependent: :destroy
        has_many :automation_actions,
                 through: :project_actions,
                 source: :aut_action,
                 class_name: 'HrzlibAutAction'


        # Get all enabled automation actions for this project.
        # Examples:
        #     project = Project.find(               project_id)    # rescue ...
        #  OR
        #     project = Project.find_by(id:         project_id)
        #     if project ...
        #  OR
        #     project = Project.find_by(identifier: 'my-project')
        #     if project ...
        #
        #     enabled_actions = project.enabled_automation_actions
        #
        #
        #   begin
        #     project = Project.find(projekt_id)
        #     enabled_actions = project.enabled_automation_actions
        #     enabled_actions.each do |action|
        #       puts "Action ID #{action.id}: #{action.b_title}"
        #     end
        #   rescue ActiveRecord::RecordNotFound
        #     Rails.logger.error "Project with ID #{projekt_id} not found"
        #   end
        #
        # @return [ActiveRecord relation of HrzlibAutAction objects]
        #         You could appy further filters to that or sort it:
        #   project = Project.find(projekt_id)
        #   enabled_actions = project.enabled_automation_actions.where(jq_on_new_ticket: 1)
        def enabled_automation_actions
          automation_actions.order(:b_title)
          # Why and how this works and filters correctly:
          # - project_actions above filters WHERE project_id = <current_project.id> (because of foreign_key: 'project_id')
          # - automation_actions uses that via "through: :project_actions"
          # So, finally ActiveRecord does this:
          #   SELECT hrzlib_aut_actions.*
          #     FROM hrzlib_aut_actions
          #    INNER JOIN hrzlib_aut_project_actions ON hrzlib_aut_actions.id = hrzlib_aut_project_actions.aut_action_id
          #    WHERE hrzlib_aut_project_actions.project_id = <project_id>
          #    ORDER BY hrzlib_aut_actions.b_title
        end  # enabled_automation_actions


        # Check if a specific automation action is enabled for this project
        def automation_action_enabled?(action_id)
          project_actions.exists?(aut_action_id: action_id)
        end  # automation_action_enabled?

      end
    end
  end  # module ProjectPatch
end  # module HrzLib


# Apply the patch
unless Project.included_modules.include?(HrzLib::ProjectPatch)
  Project.send(:include, HrzLib::ProjectPatch)
end
