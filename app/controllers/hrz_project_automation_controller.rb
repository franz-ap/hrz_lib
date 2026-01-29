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
  before_action :authorize_edit_project

  # Displays the automation settings for a project.
  # @return [void] Renders the show view with available and enabled actions.
  def show
    @available_actions  = HrzlibAutAction.order(:b_title)
    @enabled_action_ids = @project.project_actions.pluck(:aut_action_id)
  end

  # Updates the automation action assignments for a project.
  # Removes all existing assignments and creates new ones based on selected actions.
  # @return [void] Redirects to project settings with success or error flash.
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

  # Finds the project from request parameters.
  # @return [void] Sets @project or renders 404.
  def find_project
    @project = Project.find(params[:project_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Checks that the user is allowed to edit the project.
  # Uses :edit_project permission since this is a project settings tab.
  # @return [void] Denies access if user lacks permission.
  def authorize_edit_project
    deny_access unless User.current.allowed_to?(:edit_project, @project)
  end
end
