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
class CreateHrzlibProjectActions < ActiveRecord::Migration[6.1]
  def change
    # Junction table for many-to-many relationship between projects and automation actions
    create_table :hrzlib_aut_project_actions do |t|
      t.integer :project_id, null: false
      t.bigint :aut_action_id, null: false
      t.integer :created_by
      t.timestamps
    end
    
    add_index :hrzlib_aut_project_actions, [:project_id, :aut_action_id], 
              unique: true, 
              name: 'idx_project_action_unique'
    add_foreign_key :hrzlib_aut_project_actions, :projects, column: :project_id
    add_foreign_key :hrzlib_aut_project_actions, :hrzlib_aut_actions, column: :aut_action_id
  end
end
