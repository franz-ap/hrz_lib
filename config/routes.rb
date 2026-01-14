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
# Purpose: Routes configuration for HRZ Lib plugin REST API.

RedmineApp::Application.routes.draw do
  # Custom Fields REST API
  resources :hrz_custom_fields, only: [:index, :show, :create, :update, :destroy] do
    collection do
      post :validate_formula
      get :formula_fields
      get :instance_info
    end
  end

  # Automation Settings
  get 'hrz_automation_settings', to: 'hrz_automation_settings#index'

  # Conditions
  post 'hrz_automation_settings/conditions', to: 'hrz_automation_settings#create_condition'
  patch 'hrz_automation_settings/conditions/:id', to: 'hrz_automation_settings#update_condition'
  delete 'hrz_automation_settings/conditions/:id', to: 'hrz_automation_settings#destroy_condition'

  # Steps
  post 'hrz_automation_settings/steps', to: 'hrz_automation_settings#create_step'
  patch 'hrz_automation_settings/steps/:id', to: 'hrz_automation_settings#update_step'
  delete 'hrz_automation_settings/steps/:id', to: 'hrz_automation_settings#destroy_step'

  # Actions
  post 'hrz_automation_settings/actions', to: 'hrz_automation_settings#create_action'
  patch 'hrz_automation_settings/actions/:id', to: 'hrz_automation_settings#update_action'
  delete 'hrz_automation_settings/actions/:id', to: 'hrz_automation_settings#destroy_action'

  # AI Models
  post 'hrz_automation_settings/ai_models', to: 'hrz_automation_settings#create_ai_model'
  patch 'hrz_automation_settings/ai_models/:id', to: 'hrz_automation_settings#update_ai_model'
  delete 'hrz_automation_settings/ai_models/:id', to: 'hrz_automation_settings#destroy_ai_model'

  # Todos
  post 'hrz_automation_settings/todos', to: 'hrz_automation_settings#create_todo'
  patch 'hrz_automation_settings/todos/:id', to: 'hrz_automation_settings#update_todo'
  delete 'hrz_automation_settings/todos/:id', to: 'hrz_automation_settings#destroy_todo'
end
