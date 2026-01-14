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
# Purpose: Model for automation actions


class HrzlibAutAction < ActiveRecord::Base
  self.primary_key = 'b_title'
  
  belongs_to :condition1, class_name: 'HrzlibAutCondition', foreign_key: 'j_cond1_id', primary_key: 'j_condition_id', optional: true
  belongs_to :condition2, class_name: 'HrzlibAutCondition', foreign_key: 'j_cond2_id', primary_key: 'j_condition_id', optional: true
  belongs_to :condition3, class_name: 'HrzlibAutCondition', foreign_key: 'j_cond3_id', primary_key: 'j_condition_id', optional: true
  belongs_to :condition4, class_name: 'HrzlibAutCondition', foreign_key: 'j_cond4_id', primary_key: 'j_condition_id', optional: true
  belongs_to :condition5, class_name: 'HrzlibAutCondition', foreign_key: 'j_cond5_id', primary_key: 'j_condition_id', optional: true
  
  belongs_to :step1, class_name: 'HrzlibAutStep', foreign_key: 'j_step1_id', primary_key: 'j_step_id', optional: true
  belongs_to :step2, class_name: 'HrzlibAutStep', foreign_key: 'j_step2_id', primary_key: 'j_step_id', optional: true
  belongs_to :step3, class_name: 'HrzlibAutStep', foreign_key: 'j_step3_id', primary_key: 'j_step_id', optional: true
  belongs_to :step4, class_name: 'HrzlibAutStep', foreign_key: 'j_step4_id', primary_key: 'j_step_id', optional: true
  belongs_to :step5, class_name: 'HrzlibAutStep', foreign_key: 'j_step5_id', primary_key: 'j_step_id', optional: true
  
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by', optional: true
  belongs_to :updater, class_name: 'User', foreign_key: 'updated_by', optional: true
  
  validates :b_title, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :b_comment, length: { maximum: 4000 }
  
  before_save :set_user_context
  
  private
  
  def set_user_context
    if new_record?
      self.created_by = User.current.id if User.current
    end
    self.updated_by = User.current.id if User.current
  end
end  # class HrzlibAutAction
