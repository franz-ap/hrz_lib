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
# Purpose: Model for the junction table between projects and automation actions.

class HrzlibAutProjectAction < ActiveRecord::Base
  #self.table_name = 'hrzlib_aut_project_actions'    # Valid, but unnecessary, because of correct class name.

  belongs_to :project
  belongs_to :aut_action, class_name: 'HrzlibAutAction', foreign_key: 'aut_action_id'

  validates :project_id, presence: true
  validates :aut_action_id, presence: true
  validates :project_id, uniqueness: { scope: :aut_action_id }
end
