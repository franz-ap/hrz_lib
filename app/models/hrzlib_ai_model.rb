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
# Purpose: Model for AI model settings


class HrzlibAiModel < ActiveRecord::Base
  self.primary_key = 'j_key'
  
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by', optional: true
  belongs_to :updater, class_name: 'User', foreign_key: 'updated_by', optional: true
  
  validates :j_key, presence: true, uniqueness: true
  validates :b_name, presence: true, length: { maximum: 100 }
  validates :b_url, length: { maximum: 1000 }
  validates :b_api_key, length: { maximum: 100 }
  validates :b_json_post, length: { maximum: 4000 }
  validates :b_json_res_path, length: { maximum: 100 }
  
  before_save :set_user_context
  before_save :auto_fill_b_key
  
  private
  
  def set_user_context
    if new_record?
      self.created_by = User.current.id if User.current
    end
    self.updated_by = User.current.id if User.current
  end
  
  def auto_fill_b_key
    if j_key_changed? && j_key.present?
      begin
        field = HrzLib::CustomFieldHelper.get_custom_field(5)
        if field && field[:possible_val_keys] && field[:possible_values]
          idx = field[:possible_val_keys].index(j_key)
          self.b_key = field[:possible_values][idx] if idx
        end
      rescue => e
        Rails.logger.error "Error auto-filling b_key: #{e.message}"
      end
    end
  end
end  # class HrzlibAiModel
