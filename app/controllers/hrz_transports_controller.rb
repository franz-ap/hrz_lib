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
# Purpose: Controller for managing custom field transports between Redmine instances.

class HrzTransportsController < ApplicationController
  before_action :require_admin
  
  # GET /hrz_transports
  # Shows the transport comparison and execution page
  def index
    @projects = Project.all.order(:name)
    @comparison_scope = params[:comparison_scope] || 'all'
    @selected_project_id = params[:project_id]
    @transport_direction = params[:transport_direction] || 'readonly'
    @doc_issue_local = params[:doc_issue_local]
    @doc_issue_target = params[:doc_issue_target]
    
    # Get target URL from settings
    @target_url = Setting.plugin_hrz_lib['transport_target_url']
    
    if @target_url.blank?
      flash.now[:warning] = l(:warning_hrz_no_target_url)
      return
    end
    
    # Perform comparison automatically if scope is 'all' OR if project is selected
    if @comparison_scope == 'all' || (@comparison_scope == 'project' && @selected_project_id.present?)
      perform_comparison
    end
  end
  
  # POST /hrz_transports/execute
  # Executes a transport operation for a specific custom field
  def execute
    field_id = params[:field_id].to_i
    direction = params[:direction]
    doc_issue_local = params[:doc_issue_local]
    doc_issue_target = params[:doc_issue_target]
    
    result = HrzLib::TransportHelper.execute_transport(
      field_id,
      direction,
      User.current.api_key,
      doc_issue_local,
      doc_issue_target
    )
    
    if result[:success]
      flash[:notice] = l(:notice_hrz_transport_success, field_name: result[:field_name])
    else
      flash[:error] = l(:error_hrz_transport_failed, error: result[:error])
    end
    
    redirect_to hrz_transports_path(
      comparison_scope: params[:comparison_scope],
      project_id: params[:project_id],
      transport_direction: params[:transport_direction],
      doc_issue_local: doc_issue_local,
      doc_issue_target: doc_issue_target
    )
  end
  
  private
  
  # Performs the comparison between local and target custom fields
  def perform_comparison
    begin
      # Get local custom fields
      if @comparison_scope == 'all'
        @local_fields = HrzLib::CustomFieldHelper.list_custom_fields
      else
        project = Project.find(@selected_project_id)
        # Get custom fields used in this project
        @local_fields = get_project_custom_fields(project)
      end
      
      # Get target custom fields
      @target_fields = HrzLib::TransportHelper.fetch_target_custom_fields(
        User.current.api_key
      )
      
      if @target_fields.nil?
        flash.now[:error] = l(:error_hrz_cannot_fetch_target_fields)
        return
      end
      
      # Compare fields
      @comparison_results = HrzLib::TransportHelper.compare_custom_fields(
        @local_fields,
        @target_fields
      )
      
    rescue ActiveRecord::RecordNotFound
      flash.now[:error] = l(:error_project_not_found)
    rescue => e
      flash.now[:error] = l(:error_hrz_comparison_failed, error: e.message)
      Rails.logger.error "HRZ Transport: Comparison failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
  
  # Gets custom fields used in a specific project
  # Returns array of custom field hashes
  def get_project_custom_fields(project)
    fields = []
    
    # Get issue custom fields for this project's trackers
    project.trackers.each do |tracker|
      tracker.custom_fields.each do |cf|
        unless fields.any? { |f| f[:id] == cf.id }
          fields << {
            id: cf.id,
            name: cf.name,
            field_format: cf.field_format,
            customized_type: 'issue',
            is_required: cf.is_required,
            visible: cf.visible,
            is_computed: cf.respond_to?(:formula) && !cf.formula.blank?
          }
        end
      end
    end
    
    # Get project custom fields
    project.custom_fields.each do |cf|
      unless fields.any? { |f| f[:id] == cf.id }
        fields << {
          id: cf.id,
          name: cf.name,
          field_format: cf.field_format,
          customized_type: 'project',
          is_required: cf.is_required,
          visible: cf.visible,
          is_computed: cf.respond_to?(:formula) && !cf.formula.blank?
        }
      end
    end
    
    fields
  end
end
