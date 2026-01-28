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
        
        # Get all enabled automation actions for this project
        def enabled_automation_actions
          automation_actions.order(:b_title)
        end
        
        # Check if a specific automation action is enabled for this project
        def automation_action_enabled?(action_id)
          project_actions.exists?(aut_action_id: action_id)
        end
      end
    end
  end
end

# Apply the patch
unless Project.included_modules.include?(HrzLib::ProjectPatch)
  Project.send(:include, HrzLib::ProjectPatch)
end
