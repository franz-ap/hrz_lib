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
end
