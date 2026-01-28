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
# Purpose: Controller for managing automation actions within project settings.

class HrzProjectAutomationController < ApplicationController
  before_action :find_project
  before_action :authorize

  def show
    @available_actions  = HrzlibAutAction.order(:b_title)
    @enabled_action_ids = @project.project_actions.pluck(:aut_action_id)
  end

  def update
    # Get the selected action IDs from the form
    selected_action_ids = (params[:action_ids] || []).reject(&:blank?).map(&:to_i)

    # Start a transaction to ensure data consistency
    HrzlibAutProjectAction.transaction do
      # Remove all existing associations for this project
      @project.project_actions.destroy_all

      # Create new associations
      selected_action_ids.each do |action_id|
        HrzlibAutProjectAction.create!(
          project_id:    @project.id,
          aut_action_id: action_id,
          created_by:    User.current.id
        )
      end
    end

    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, tab: 'automation')
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = l(:error_automation_update_failed, error: e.message)
    redirect_to settings_project_path(@project, tab: 'automation')
  end

  private

  def find_project
    @project = Project.find(params[:project_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
