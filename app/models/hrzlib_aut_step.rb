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
# Purpose: Model for automation steps


class HrzlibAutStep < ActiveRecord::Base
  self.primary_key = 'j_step_id'

  belongs_to :todo, class_name: 'HrzlibAutTodo', foreign_key: 'b_todo', primary_key: 'b_key', optional: true
  belongs_to :issue_template, class_name: 'Issue', foreign_key: 'j_issue_template_id', optional: true
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by', optional: true
  belongs_to :updater, class_name: 'User', foreign_key: 'updated_by', optional: true

  validates :b_title, presence: true, length: { maximum: 100 }
  validates :b_comment, length: { maximum: 4000 }
  validates :b_hrz_prep, length: { maximum: 4000 }
  validates :b_todo, length: { maximum: 25 }
  validates :b_project_id, length: { maximum: 50 }
  validates :b_key_abbr, length: { maximum: 50 }
  validates :b_hrz_clean, length: { maximum: 4000 }

  before_create :set_created_by
  before_save :set_updated_by

  private

  def set_created_by
    self.created_by = User.current.id if User.current
  end

  def set_updated_by
    self.updated_by = User.current.id if User.current
  end
end  # class HrzlibAutStep
