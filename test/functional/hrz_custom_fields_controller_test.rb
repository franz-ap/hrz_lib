#-------------------------------------------------------------------------------------------#
# Redmine utility/library plugin. Provides common functions to other plugins + REST API.    #
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
# Purpose: Functional tests for HrzCustomFieldsController REST API.
#
# * Index: JSON/XML, filtered by type, admin/non-admin access
# * Show: JSON/XML, 404 for non-existing fields
# * Create: all field types, validation, assign project/tracker
# * Update: PUT/PATCH, possible values, formula updates
# * Destroy: success, error handling
# * validate_formula: valid/invalid formulas
# * formula_fields: Get available fields for formulas
# * API auth: API key in header, admin rights



require_relative '../test_helper'

class HrzCustomFieldsControllerTest < ActionController::TestCase
  fixtures :users, :projects, :roles, :members, :member_roles

  def setup
    @admin = User.find(1)
    @user = User.find(2)
    @request.session[:user_id] = @admin.id
  end

  def teardown
    # Clean up custom fields created during tests
    CustomField.where("name LIKE 'Test API %'").destroy_all
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # index action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should get index as JSON" do
    get :index, format: 'json'
    
    assert_response :success
    assert_equal 'application/json', @response.media_type
    
    json = JSON.parse(@response.body)
    assert json.key?('custom_fields')
    assert_kind_of Array, json['custom_fields']
  end

  test "should get index as XML" do
    get :index, format: 'xml'
    
    assert_response :success
    assert_equal 'application/xml', @response.media_type
  end

  test "should filter index by customized type" do
    # Create test fields
    IssueCustomField.create!(name: 'Test API Issue Field', field_format: 'string')
    ProjectCustomField.create!(name: 'Test API Project Field', field_format: 'string')
    
    get :index, params: {customized_type: 'issue'}, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['custom_fields'].all? { |f| f['customized_type'] == 'issue' }
  end

  test "should allow index access for non-admin with API auth" do
    @request.session[:user_id] = @user.id
    
    get :index, format: 'json'
    
    assert_response :success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # show action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should show custom field as JSON" do
    field = IssueCustomField.create!(
      name: 'Test API Show Field',
      field_format: 'string',
      description: 'Test description'
    )
    
    get :show, params: {id: field.id}, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.key?('custom_field')
    assert_equal field.name, json['custom_field']['name']
    assert_equal field.description, json['custom_field']['description']
  end

  test "should show custom field as XML" do
    field = IssueCustomField.create!(
      name: 'Test API Show XML',
      field_format: 'string'
    )
    
    get :show, params: {id: field.id}, format: 'xml'
    
    assert_response :success
  end

  test "should return 404 for nonexistent field" do
    get :show, params: {id: 99999}, format: 'json'
    
    assert_response :not_found
  end

  test "should allow show access for non-admin" do
    field = IssueCustomField.create!(name: 'Test API Show', field_format: 'string')
    @request.session[:user_id] = @user.id
    
    get :show, params: {id: field.id}, format: 'json'
    
    assert_response :success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # create action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should create custom field as JSON" do
    assert_difference 'CustomField.count' do
      post :create, params: {
        custom_field: {
          name: 'Test API Created Field',
          field_format: 'string',
          customized_type: 'issue',
          description: 'Test'
        }
      }, format: 'json'
    end
    
    assert_response :created
    json = JSON.parse(@response.body)
    assert json.key?('custom_field')
    assert_equal 'Test API Created Field', json['custom_field']['name']
  end

  test "should create custom field as XML" do
    assert_difference 'CustomField.count' do
      post :create, params: {
        custom_field: {
          name: 'Test API XML Field',
          field_format: 'string',
          customized_type: 'issue'
        }
      }, format: 'xml'
    end
    
    assert_response :created
  end

  test "should create list custom field with possible values" do
    post :create, params: {
      custom_field: {
        name: 'Test API List',
        field_format: 'list',
        customized_type: 'issue',
        possible_values: ['Low', 'Medium', 'High'],
        default_value: 'Medium'
      }
    }, format: 'json'
    
    assert_response :created
    json = JSON.parse(@response.body)
    field = CustomField.find(json['custom_field']['id'])
    assert_equal ['Low', 'Medium', 'High'], field.possible_values
    assert_equal 'Medium', field.default_value
  end

  test "should create required custom field" do
    post :create, params: {
      custom_field: {
        name: 'Test API Required',
        field_format: 'string',
        customized_type: 'issue',
        is_required: true
      }
    }, format: 'json'
    
    assert_response :created
    json = JSON.parse(@response.body)
    assert json['custom_field']['is_required']
  end

  test "should create custom field with validation options" do
    post :create, params: {
      custom_field: {
        name: 'Test API Validated',
        field_format: 'string',
        customized_type: 'issue',
        regexp: '^[A-Z]',
        min_length: 3,
        max_length: 50
      }
    }, format: 'json'
    
    assert_response :created
    json = JSON.parse(@response.body)
    field = CustomField.find(json['custom_field']['id'])
    assert_equal '^[A-Z]', field.regexp
    assert_equal 3, field.min_length
    assert_equal 50, field.max_length
  end

  test "should create custom field with project assignment" do
    project = Project.first
    
    post :create, params: {
      custom_field: {
        name: 'Test API Project Specific',
        field_format: 'string',
        customized_type: 'issue',
        is_for_all: false,
        project_ids: [project.id]
      }
    }, format: 'json'
    
    assert_response :created
    json = JSON.parse(@response.body)
    field = CustomField.find(json['custom_field']['id'])
    assert_not field.is_for_all
    assert_includes field.projects.map(&:id), project.id
  end

  test "should create custom field with tracker assignment" do
    tracker = Tracker.first
    
    post :create, params: {
      custom_field: {
        name: 'Test API Tracker Specific',
        field_format: 'string',
        customized_type: 'issue',
        tracker_ids: [tracker.id]
      }
    }, format: 'json'
    
    assert_response :created
    json = JSON.parse(@response.body)
    field = IssueCustomField.find(json['custom_field']['id'])
    assert_includes field.tracker_ids, tracker.id
  end

  test "should return error for missing parameters" do
    post :create, params: {
      custom_field: {
        name: 'Test Incomplete'
      }
    }, format: 'json'
    
    assert_response :unprocessable_entity
    json = JSON.parse(@response.body)
    assert json.key?('error')
  end

  test "should require admin for create" do
    @request.session[:user_id] = @user.id
    
    post :create, params: {
      custom_field: {
        name: 'Test',
        field_format: 'string',
        customized_type: 'issue'
      }
    }, format: 'json'
    
    assert_response :forbidden
  end

  test "should create computed custom field if plugin available" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    post :create, params: {
      custom_field: {
        name: 'Test API Computed',
        field_format: 'float',
        customized_type: 'issue',
        is_computed: true,
        formula: 'cfs[1] * cfs[2]'
      }
    }, format: 'json'
    
    assert_response :created
    json = JSON.parse(@response.body)
    field = CustomField.find(json['custom_field']['id'])
    assert_equal 'cfs[1] * cfs[2]', field.formula
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # update action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should update custom field with PUT" do
    field = IssueCustomField.create!(
      name: 'Test API Update',
      field_format: 'string'
    )
    
    put :update, params: {
      id: field.id,
      custom_field: {
        description: 'Updated description',
        is_required: true
      }
    }, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal 'Updated description', json['custom_field']['description']
    
    field.reload
    assert_equal 'Updated description', field.description
    assert field.is_required
  end

  test "should update custom field with PATCH" do
    field = IssueCustomField.create!(
      name: 'Test API Patch',
      field_format: 'string'
    )
    
    patch :update, params: {
      id: field.id,
      custom_field: {
        name: 'Updated Name'
      }
    }, format: 'json'
    
    assert_response :success
    field.reload
    assert_equal 'Updated Name', field.name
  end

  test "should update list field possible values" do
    field = IssueCustomField.create!(
      name: 'Test API Update List',
      field_format: 'list',
      possible_values: ['A', 'B', 'C']
    )
    
    put :update, params: {
      id: field.id,
      custom_field: {
        possible_values: ['A', 'B', 'C', 'D', 'E']
      }
    }, format: 'json'
    
    assert_response :success
    field.reload
    assert_equal ['A', 'B', 'C', 'D', 'E'], field.possible_values
  end

  test "should update computed field formula if plugin available" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    field = IssueCustomField.create!(
      name: 'Test API Update Formula',
      field_format: 'float',
      formula: 'cfs[1] * cfs[2]'
    )
    
    put :update, params: {
      id: field.id,
      custom_field: {
        formula: 'cfs[1] * cfs[2] * 1.19'
      }
    }, format: 'json'
    
    assert_response :success
    field.reload
    assert_equal 'cfs[1] * cfs[2] * 1.19', field.formula
  end

  test "should return error for update with invalid field" do
    put :update, params: {
      id: 99999,
      custom_field: {
        description: 'Test'
      }
    }, format: 'json'
    
    assert_response :unprocessable_entity
  end

  test "should require admin for update" do
    field = IssueCustomField.create!(name: 'Test', field_format: 'string')
    @request.session[:user_id] = @user.id
    
    put :update, params: {
      id: field.id,
      custom_field: {description: 'Test'}
    }, format: 'json'
    
    assert_response :forbidden
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # destroy action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should destroy custom field" do
    field = IssueCustomField.create!(
      name: 'Test API Destroy',
      field_format: 'string'
    )
    
    assert_difference 'CustomField.count', -1 do
      delete :destroy, params: {id: field.id}, format: 'json'
    end
    
    assert_response :no_content
  end

  test "should destroy custom field as XML" do
    field = IssueCustomField.create!(
      name: 'Test API Destroy XML',
      field_format: 'string'
    )
    
    assert_difference 'CustomField.count', -1 do
      delete :destroy, params: {id: field.id}, format: 'xml'
    end
    
    assert_response :no_content
  end

  test "should return error when destroying nonexistent field" do
    delete :destroy, params: {id: 99999}, format: 'json'
    
    assert_response :unprocessable_entity
  end

  test "should require admin for destroy" do
    field = IssueCustomField.create!(name: 'Test', field_format: 'string')
    @request.session[:user_id] = @user.id
    
    delete :destroy, params: {id: field.id}, format: 'json'
    
    assert_response :forbidden
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # validate_formula action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should validate formula" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    post :validate_formula, params: {
      formula: 'cfs[1] * cfs[2]',
      customized_type: 'issue'
    }, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert json['valid']
    assert_nil json['error']
  end

  test "should detect invalid formula" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    post :validate_formula, params: {
      formula: 'invalid ruby code {',
      customized_type: 'issue'
    }, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert_not json['valid']
    assert_not_nil json['error']
  end

  test "should return error for missing formula parameter" do
    post :validate_formula, params: {}, format: 'json'
    
    assert_response :unprocessable_entity
    json = JSON.parse(@response.body)
    assert json.key?('error')
  end

  test "should allow validate_formula for non-admin" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    @request.session[:user_id] = @user.id
    
    post :validate_formula, params: {
      formula: 'cfs[1] * cfs[2]'
    }, format: 'json'
    
    assert_response :success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # formula_fields action tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should get formula fields" do
    # Create some test fields
    IssueCustomField.create!(name: 'Test API Formula Field 1', field_format: 'int')
    IssueCustomField.create!(name: 'Test API Formula Field 2', field_format: 'float')
    
    get :formula_fields, params: {customized_type: 'issue'}, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.key?('custom_fields')
    assert json.key?('attributes')
    assert_kind_of Array, json['custom_fields']
    assert_kind_of Array, json['attributes']
  end

  test "should get formula fields as XML" do
    get :formula_fields, params: {customized_type: 'issue'}, format: 'xml'
    
    assert_response :success
  end

  test "should default to issue type for formula fields" do
    get :formula_fields, format: 'json'
    
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.key?('custom_fields')
    assert json.key?('attributes')
  end

  test "should allow formula_fields for non-admin" do
    @request.session[:user_id] = @user.id
    
    get :formula_fields, params: {customized_type: 'issue'}, format: 'json'
    
    assert_response :success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # API authentication tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should accept API key in header for index" do
    @request.session[:user_id] = nil
    @request.headers['X-Redmine-API-Key'] = @admin.api_key
    
    get :index, format: 'json'
    
    assert_response :success
  end

  test "should accept API key in header for create" do
    @request.session[:user_id] = nil
    @request.headers['X-Redmine-API-Key'] = @admin.api_key
    
    post :create, params: {
      custom_field: {
        name: 'Test API Key Create',
        field_format: 'string',
        customized_type: 'issue'
      }
    }, format: 'json'
    
    assert_response :created
  end

  test "should reject non-admin API key for create" do
    @request.session[:user_id] = nil
    @request.headers['X-Redmine-API-Key'] = @user.api_key
    
    post :create, params: {
      custom_field: {
        name: 'Test',
        field_format: 'string',
        customized_type: 'issue'
      }
    }, format: 'json'
    
    assert_response :forbidden
  end
end
