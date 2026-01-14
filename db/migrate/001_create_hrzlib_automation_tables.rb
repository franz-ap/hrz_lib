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
class CreateHrzlibAutomationTables < ActiveRecord::Migration[6.1]
  def change
    # Condition for automatic actions
    create_table :hrzlib_aut_conditions, primary_key: :j_condition_id do |t|
      t.string :b_cond_question, limit: 100
      t.string :b_cond_hrz, limit: 4000
      t.integer :created_by
      t.integer :updated_by
      t.timestamps
    end

    # List of available Todos
    create_table :hrzlib_aut_todos, id: false do |t|
      t.string :b_key, limit: 25, primary_key: true
      t.string :b_name, limit: 100
      t.integer :j_sort, limit: 1
      t.integer :created_by
      t.integer :updated_by
      t.timestamps
    end
    add_index :hrzlib_aut_todos, [:j_sort, :b_name]

    # Step in an automatic action
    create_table :hrzlib_aut_steps, primary_key: :j_step_id do |t|
      t.string :b_title, limit: 100
      t.string :b_comment, limit: 4000
      t.string :b_hrz_prep, limit: 4000
      t.string :b_todo, limit: 25
      t.integer :jq_related, limit: 1
      t.integer :jq_subticket, limit: 1
      t.integer :j_issue_template_id
      t.string :b_project_id, limit: 50
      t.integer :jq_only_1x, limit: 1
      t.string :b_key_abbr, limit: 50
      t.string :b_hrz_clean, limit: 4000
      t.integer :created_by
      t.integer :updated_by
      t.timestamps
    end
    add_foreign_key :hrzlib_aut_steps, :hrzlib_aut_todos, column: :b_todo, primary_key: :b_key

    # Automatic action
    create_table :hrzlib_aut_actions do |t|
      t.string :b_title, limit: 100
      t.string :b_comment, limit: 4000
      t.integer :jq_on_new_ticket, limit: 1
      t.integer :jq_on_ticket_update, limit: 1
      t.integer :j_cond1_id
      t.integer :j_cond2_id
      t.integer :j_cond3_id
      t.integer :j_cond4_id
      t.integer :j_cond5_id
      t.integer :j_step1_id
      t.integer :j_step2_id
      t.integer :j_step3_id
      t.integer :j_step4_id
      t.integer :j_step5_id
      t.integer :created_by
      t.integer :updated_by
      t.timestamps
    end
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_conditions, column: :j_cond1_id, primary_key: :j_condition_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_conditions, column: :j_cond2_id, primary_key: :j_condition_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_conditions, column: :j_cond3_id, primary_key: :j_condition_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_conditions, column: :j_cond4_id, primary_key: :j_condition_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_conditions, column: :j_cond5_id, primary_key: :j_condition_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_steps, column: :j_step1_id, primary_key: :j_step_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_steps, column: :j_step2_id, primary_key: :j_step_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_steps, column: :j_step3_id, primary_key: :j_step_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_steps, column: :j_step4_id, primary_key: :j_step_id
    add_foreign_key :hrzlib_aut_actions, :hrzlib_aut_steps, column: :j_step5_id, primary_key: :j_step_id

    # AI Model
    create_table :hrzlib_ai_models, id: false do |t|
      t.integer :j_key, primary_key: true
      t.string :b_key, limit: 50
      t.string :b_name, limit: 100
      t.string :b_url, limit: 1000
      t.string :b_api_key, limit: 100
      t.string :b_json_post, limit: 4000
      t.string :b_json_res_path, limit: 100
      t.integer :created_by
      t.integer :updated_by
      t.timestamps
    end
  end
end
