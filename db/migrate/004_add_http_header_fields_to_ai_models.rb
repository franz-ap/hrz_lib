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
# Purpose: Add HTTP header fields to AI models table for flexible API authentication

class AddHttpHeaderFieldsToAiModels < ActiveRecord::Migration[6.1]
  def change
    # API Key header name (e.g., "Authorization", "api-key")
    add_column :hrzlib_ai_models, :b_hdr_name_api_key, :string, limit: 30

    # Auxiliary HTTP header 1
    add_column :hrzlib_ai_models, :b_hdr_name_aux1,    :string, limit: 30
    add_column :hrzlib_ai_models, :b_hdr_val_aux1,     :string, limit: 100

    # Auxiliary HTTP header 2
    add_column :hrzlib_ai_models, :b_hdr_name_aux2,    :string, limit: 30
    add_column :hrzlib_ai_models, :b_hdr_val_aux2,     :string, limit: 100
  end
end
