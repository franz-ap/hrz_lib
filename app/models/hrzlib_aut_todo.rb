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
# Purpose: Model for automation ToDos


class HrzlibAutTodo < ActiveRecord::Base
  self.primary_key = 'b_key'
  
  has_many :steps, class_name: 'HrzlibAutStep', foreign_key: 'b_todo'
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by', optional: true
  belongs_to :updater, class_name: 'User', foreign_key: 'updated_by', optional: true
  
  validates :b_key, presence: true, uniqueness: true, length: { maximum: 25 }
  validates :b_name, presence: true, length: { maximum: 100 }
  
  default_scope { order(:j_sort, :b_name) }
  
  before_save :set_user_context
  
  private
  
  def set_user_context
    if new_record?
      self.created_by = User.current.id if User.current
    end
    self.updated_by = User.current.id if User.current
  end
end  # class HrzlibAutTodo
