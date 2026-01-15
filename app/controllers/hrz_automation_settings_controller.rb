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
# Purpose: Controller for hrz_lib plugin settings


class HrzAutomationSettingsController < ApplicationController
  before_action :require_admin

  def index
    @tab = params[:tab] || 'conditions'

    case @tab
    when 'conditions'
      @conditions = HrzlibAutCondition.all.order(:j_condition_id)
      @condition = HrzlibAutCondition.new
    when 'steps'
      @steps = HrzlibAutStep.all.order(:j_step_id)
      @step = HrzlibAutStep.new
      @todos = HrzlibAutTodo.sorted
    when 'actions'
      @actions = HrzlibAutAction.all.order(:b_title)
      @action = HrzlibAutAction.new
      @conditions = HrzlibAutCondition.all
      @steps = HrzlibAutStep.all
    when 'ai_models'
      @ai_models = HrzlibAiModel.all.order(:j_key)
      @ai_model = HrzlibAiModel.new
      @available_models = fetch_available_ai_models
    when 'miscellaneous'
      @todos = HrzlibAutTodo.sorted
      @todo = HrzlibAutTodo.new
    end
  end

  # Conditions
  def create_condition
    @condition = HrzlibAutCondition.new(condition_params)
    if @condition.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to hrz_automation_settings_path(tab: 'conditions')
    else
      @conditions = HrzlibAutCondition.all.order(:j_condition_id)
      @tab = 'conditions'
      render :index
    end
  end

  def update_condition
    @condition = HrzlibAutCondition.find(params[:id])
    if @condition.update(condition_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to hrz_automation_settings_path(tab: 'conditions')
    else
      @conditions = HrzlibAutCondition.all.order(:j_condition_id)
      @tab = 'conditions'
      render :index
    end
  end

  def destroy_condition
    @condition = HrzlibAutCondition.find(params[:id])
    @condition.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to hrz_automation_settings_path(tab: 'conditions')
  end

  # Steps
  def create_step
    @step = HrzlibAutStep.new(step_params)
    if @step.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to hrz_automation_settings_path(tab: 'steps')
    else
      @steps = HrzlibAutStep.all.order(:j_step_id)
      @todos = HrzlibAutTodo.sorted
      @tab = 'steps'
      render :index
    end
  end

  def update_step
    @step = HrzlibAutStep.find(params[:id])
    if @step.update(step_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to hrz_automation_settings_path(tab: 'steps')
    else
      @steps = HrzlibAutStep.all.order(:j_step_id)
      @todos = HrzlibAutTodo.all
      @tab = 'steps'
      render :index
    end
  end

  def destroy_step
    @step = HrzlibAutStep.find(params[:id])
    @step.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to hrz_automation_settings_path(tab: 'steps')
  end

  # Actions
  def create_action
    @action = HrzlibAutAction.new(action_params)
    if @action.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to hrz_automation_settings_path(tab: 'actions')
    else
      @actions = HrzlibAutAction.all.order(:b_title)
      @conditions = HrzlibAutCondition.all
      @steps = HrzlibAutStep.all
      @tab = 'actions'
      render :index
    end
  end

  def update_action
    @action = HrzlibAutAction.find(params[:id])
    if @action.update(action_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to hrz_automation_settings_path(tab: 'actions')
    else
      @actions = HrzlibAutAction.all.order(:b_title)
      @conditions = HrzlibAutCondition.all
      @steps = HrzlibAutStep.all
      @tab = 'actions'
      render :index
    end
  end

  def destroy_action
    @action = HrzlibAutAction.find(params[:id])
    @action.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to hrz_automation_settings_path(tab: 'actions')
  end

  # AI Models
  def create_ai_model
    @ai_model = HrzlibAiModel.new(ai_model_params)
    if @ai_model.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to hrz_automation_settings_path(tab: 'ai_models')
    else
      @ai_models = HrzlibAiModel.all.order(:j_key)
      @available_models = fetch_available_ai_models
      @tab = 'ai_models'
      render :index
    end
  end

  def update_ai_model
    @ai_model = HrzlibAiModel.find(params[:id])
    if @ai_model.update(ai_model_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to hrz_automation_settings_path(tab: 'ai_models')
    else
      @ai_models = HrzlibAiModel.all.order(:j_key)
      @available_models = fetch_available_ai_models
      @tab = 'ai_models'
      render :index
    end
  end

  def destroy_ai_model
    @ai_model = HrzlibAiModel.find(params[:id])
    @ai_model.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to hrz_automation_settings_path(tab: 'ai_models')
  end

  # Todos
  def create_todo
    @todo = HrzlibAutTodo.new(todo_params)
    if @todo.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to hrz_automation_settings_path(tab: 'miscellaneous')
    else
      @todos = HrzlibAutTodo.all
      @tab = 'miscellaneous'
      render :index
    end
  end

  def update_todo
    @todo = HrzlibAutTodo.find(params[:id])
    if @todo.update(todo_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to hrz_automation_settings_path(tab: 'miscellaneous')
    else
      @todos = HrzlibAutTodo.all
      @tab = 'miscellaneous'
      render :index
    end
  end

  def destroy_todo
    @todo = HrzlibAutTodo.find(params[:id])
    @todo.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to hrz_automation_settings_path(tab: 'miscellaneous')
  end

  # Manual action to auto-fill AI model b_key
  def auto_fill_ai_model_key
    @ai_model = HrzlibAiModel.find(params[:id])
    @ai_model.auto_fill_b_key
    if @ai_model.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:notice_failed_update)
    end
    redirect_to hrz_automation_settings_path(tab: 'ai_models')
  end

  private

  def condition_params
    params.require(:hrzlib_aut_condition).permit(:b_cond_question, :b_cond_hrz)
  end

  def step_params
    params.require(:hrzlib_aut_step).permit(
      :b_title, :b_comment, :b_hrz_prep, :b_todo, :jq_related,
      :jq_subticket, :j_issue_template_id, :b_project_id,
      :jq_only_1x, :b_key_abbr, :b_hrz_clean
    )
  end

  def action_params
    params.require(:hrzlib_aut_action).permit(
      :b_title, :b_comment, :jq_on_new_ticket, :jq_on_ticket_update,
      :j_cond1_id, :j_cond2_id, :j_cond3_id, :j_cond4_id, :j_cond5_id,
      :j_step1_id, :j_step2_id, :j_step3_id, :j_step4_id, :j_step5_id
    )
  end

  def ai_model_params
    params.require(:hrzlib_ai_model).permit(
      :j_key, :b_name, :b_url, :b_api_key, :b_json_post, :b_json_res_path
    )
  end

  def todo_params
    params.require(:hrzlib_aut_todo).permit(:b_key, :b_name, :j_sort)
  end

  def fetch_available_ai_models
    begin
      field = HrzLib::CustomFieldHelper.get_custom_field(ProjectCustomField.find_by(name: 'AI Model')&.id)
      if field && field[:possible_val_keys] && field[:possible_values]
        field[:possible_val_keys].zip(field[:possible_values]).to_h
      else
        {}
      end
    rescue => e
      Rails.logger.error "Error fetching AI models: #{e.message}"
      {}
    end
  end
end  # class HrzAutomationSettingsController
