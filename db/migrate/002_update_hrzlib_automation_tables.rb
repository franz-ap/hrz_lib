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
class UpdateHrzlibAutomationTables < ActiveRecord::Migration[6.1]
  def change
    # Rename column b_key_abbr to b_key_1x in table hrzlib_aut_steps,
    # because the new name explains better, what this column is good for.
    rename_column :hrzlib_aut_steps, :b_key_abbr, :b_key_1x

    # Remove column b_name from table hrzlib_ai_models,
    # because it held duplicate information. We already have it in the CustomField.
    remove_column :hrzlib_ai_models, :b_name, :string
  end
end
