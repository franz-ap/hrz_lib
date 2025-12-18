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
# Purpose: REST API controller for managing custom fields.

class HrzCustomFieldsController < ApplicationController
  accept_api_auth :index, :show, :create, :update, :destroy, :validate_formula, :formula_fields, :instance_info
  
  # Skip sudo mode for API endpoints - they use API key authentication
  #skip_before_action :require_sudo_mode
  
  before_action :require_admin, except: [:index, :show, :validate_formula, :formula_fields, :instance_info]
  before_action :require_api_authentication, only: [:instance_info]
  before_action :find_custom_field, only: [:show, :update, :destroy]
  
  # GET /hrz_custom_fields/instance_info.xml
  # GET /hrz_custom_fields/instance_info.json
  # Returns information about this Redmine instance
  def instance_info
    Rails.logger.info "HRZ API: instance_info called by user ##{User.current.id}"
    
    begin
      info = {
        app_title: Setting.app_title || 'Redmine',
        host_name: Setting.host_name || request.host,
        protocol: Setting.protocol || 'https',
        redmine_version: Redmine::VERSION.to_s,
        plugin_version: Redmine::Plugin.find(:hrz_lib).version,
        custom_fields_count: CustomField.count,
        issue_custom_fields_count: IssueCustomField.count,
        project_custom_fields_count: ProjectCustomField.count,
        api_enabled: Setting.rest_api_enabled?,
        current_user: {
          id: User.current.id,
          login: User.current.login,
          firstname: User.current.firstname,
          lastname: User.current.lastname,
          admin: User.current.admin?
        }
      }
      
      Rails.logger.info "HRZ API: instance_info successful - #{info[:app_title]}"
      
      respond_to do |format|
        format.json { render json: {instance_info: info} }
        format.xml { render xml: {instance_info: info} }
      end
      
    rescue => e
      Rails.logger.error "HRZ API: instance_info failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { render json: {error: e.message}, status: :internal_server_error }
        format.xml { render xml: {error: e.message}, status: :internal_server_error }
      end
    end
  end
  
  # GET /hrz_custom_fields.xml
  # GET /hrz_custom_fields.json
  # Lists all custom fields or filters by type
  def index
    customized_type = params[:customized_type]
    @custom_fields = HrzLib::CustomFieldHelper.list_custom_fields(customized_type)
    
    respond_to do |format|
      format.json { render json: {custom_fields: @custom_fields} }
      format.xml { render xml: {custom_fields: @custom_fields} }
    end
  end
  
  # GET /hrz_custom_fields/:id.xml
  # GET /hrz_custom_fields/:id.json
  # Shows details of a specific custom field
  def show
    @custom_field = HrzLib::CustomFieldHelper.get_custom_field(@custom_field_id)
    
    if @custom_field
      respond_to do |format|
        format.json { render json: {custom_field: @custom_field} }
        format.xml { render xml: {custom_field: @custom_field} }
      end
    else
      render_404
    end
  end
  
  # POST /hrz_custom_fields.xml
  # POST /hrz_custom_fields.json
  # Creates a new custom field
  def create
    cf_params = custom_field_params
    
    # Extract required parameters
    name = cf_params[:name]
    field_format = cf_params[:field_format]
    customized_type = cf_params[:customized_type]
    
    unless name && field_format && customized_type
      render json: {
        error: 'Missing required parameters: name, field_format, customized_type'
      }, status: :unprocessable_entity
      return
    end
    
    # Extract options
    options = cf_params.except(:name, :field_format, :customized_type)
    
    # Create the custom field
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      name,
      field_format,
      customized_type,
      options.to_h
    )
    
    if field_id
      @custom_field = HrzLib::CustomFieldHelper.get_custom_field(field_id)
      respond_to do |format|
        format.json { render json: {custom_field: @custom_field}, status: :created }
        format.xml { render xml: {custom_field: @custom_field}, status: :created }
      end
    else
      render json: {error: 'Failed to create custom field'}, status: :unprocessable_entity
    end
  end
  
  # PUT /hrz_custom_fields/:id.xml
  # PUT /hrz_custom_fields/:id.json
  # PATCH /hrz_custom_fields/:id.xml
  # PATCH /hrz_custom_fields/:id.json
  # Updates an existing custom field
  def update
    cf_params = custom_field_params
    
    success = HrzLib::CustomFieldHelper.update_custom_field(@custom_field_id, cf_params.to_h)
    
    if success
      @custom_field = HrzLib::CustomFieldHelper.get_custom_field(@custom_field_id)
      respond_to do |format|
        format.json { render json: {custom_field: @custom_field} }
        format.xml { render xml: {custom_field: @custom_field} }
      end
    else
      render json: {error: 'Failed to update custom field'}, status: :unprocessable_entity
    end
  end
  
  # DELETE /hrz_custom_fields/:id.xml
  # DELETE /hrz_custom_fields/:id.json
  # Deletes a custom field
  def destroy
    success = HrzLib::CustomFieldHelper.delete_custom_field(@custom_field_id)
    
    if success
      head :no_content
    else
      render json: {error: 'Failed to delete custom field'}, status: :unprocessable_entity
    end
  end
  
  # POST /hrz_custom_fields/validate_formula.xml
  # POST /hrz_custom_fields/validate_formula.json
  # Validates a formula without creating a field
  def validate_formula
    formula = params[:formula]
    customized_type = params[:customized_type] || 'issue'
    
    unless formula
      render json: {error: 'Missing required parameter: formula'}, status: :unprocessable_entity
      return
    end
    
    result = HrzLib::CustomFieldHelper.validate_formula(formula, customized_type)
    
    respond_to do |format|
      format.json { render json: result }
      format.xml { render xml: result }
    end
  end
  
  # GET /hrz_custom_fields/formula_fields.xml
  # GET /hrz_custom_fields/formula_fields.json
  # Gets available fields for use in formulas
  def formula_fields
    customized_type = params[:customized_type] || 'issue'
    
    fields = HrzLib::CustomFieldHelper.get_formula_fields(customized_type)
    
    respond_to do |format|
      format.json { render json: fields }
      format.xml { render xml: fields }
    end
  end
  
  private
  
  def find_custom_field
    @custom_field_id = params[:id].to_i
  end
  
  def custom_field_params
    params.require(:custom_field).permit(
      :name,
      :description,
      :field_format,
      :customized_type,
      :is_required,
      :is_for_all,
      :visible,
      :searchable,
      :multiple,
      :default_value,
      :regexp,
      :min_length,
      :max_length,
      :formula,
      :is_computed,
      possible_values: [],
      project_ids: [],
      tracker_ids: [],
      role_ids: []
    )
  end
  
  def require_api_authentication
    unless User.current.logged?
      render_error status: 401
      return false
    end
  end
end
