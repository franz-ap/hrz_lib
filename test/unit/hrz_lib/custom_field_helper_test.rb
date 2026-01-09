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
# Purpose: Unit tests for HrzLib::CustomFieldHelper module.
#
# * All field types: string, text, int, float, date, bool, list, user, link
# * options: required, validation (regexp, min/max length), default values
# * Lists: Single-select, Multi-select with possible_values
# * Assignments: projects, trackers, roles
# * CRUD operations: create, update, delete, get, list
# * Computed fields: formula validation, get formula fields (if plugin is installed)
# * Error handling: invalid formats, missing parameters



require_relative '../../test_helper'

class CustomFieldHelperTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses, :roles

  def setup
    @user = User.find(1)
    User.current = @user
  end

  def teardown
    User.current = nil
    # Clean up custom fields created during tests
    CustomField.where("name LIKE 'Test %'").destroy_all
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # create_custom_field tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should create basic string custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test String Field',
      'string',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'Test String Field', field.name
    assert_equal 'string', field.field_format
    assert_instance_of IssueCustomField, field
  end

  test "should create text custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Text Field',
      'text',
      'issue',
      description: 'A text field'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'text', field.field_format
    assert_equal 'A text field', field.description
  end

  test "should create integer custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Int Field',
      'int',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'int', field.field_format
  end

  test "should create float custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Float Field',
      'float',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'float', field.field_format
  end

  test "should create date custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Date Field',
      'date',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'date', field.field_format
  end

  test "should create boolean custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Bool Field',
      'bool',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'bool', field.field_format
  end

  test "should create list custom field with possible values" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test List Field',
      'list',
      'issue',
      possible_values: ['Low', 'Medium', 'High', 'Critical'],
      default_value: 'Medium'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'list', field.field_format
    assert_equal ['Low', 'Medium', 'High', 'Critical'], field.possible_values
    assert_equal 'Medium', field.default_value
  end

  test "should create multi-select list custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Multi List Field',
      'list',
      'issue',
      possible_values: ['Bug', 'Feature', 'Enhancement'],
      multiple: true
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert field.multiple
  end

  test "should create user custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test User Field',
      'user',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'user', field.field_format
  end

  test "should create link custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Link Field',
      'link',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'link', field.field_format
  end

  test "should create key/value custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Key/Value Field',
      'key_value',
      'issue'
    )

    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'key_value', field.field_format
  end

  test "should create key/value custom field with default value" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Key/Value With Defaults',
      'key_value',
      'issue',
      default_value: "key1=value1\nkey2=value2\nkey3=value3"
    )

    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'key_value', field.field_format
    assert_equal "key1=value1\nkey2=value2\nkey3=value3", field.default_value
  end

  test "should create required custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Required Field',
      'string',
      'issue',
      is_required: true
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert field.is_required
  end

  test "should create custom field with validation" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Validated Field',
      'string',
      'issue',
      regexp: '^[A-Z]',
      min_length: 3,
      max_length: 50
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal '^[A-Z]', field.regexp
    assert_equal 3, field.min_length
    assert_equal 50, field.max_length
  end

  test "should create custom field not for all projects" do
    project = Project.first
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Project Specific Field',
      'string',
      'issue',
      is_for_all: false,
      project_ids: [project.id]
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_not field.is_for_all
    assert_includes field.projects.map(&:id), project.id
  end

  test "should create custom field for specific trackers" do
    tracker = Tracker.first
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Tracker Specific Field',
      'string',
      'issue',
      tracker_ids: [tracker.id]
    )
    
    assert_not_nil field_id
    field = IssueCustomField.find(field_id)
    assert_includes field.tracker_ids, tracker.id
  end

  test "should create custom field for different types" do
    types = {
      'issue' => IssueCustomField,
      'project' => ProjectCustomField,
      'user' => UserCustomField,
      'time_entry' => TimeEntryCustomField
    }
    
    types.each do |type, klass|
      field_id = HrzLib::CustomFieldHelper.create_custom_field(
        "Test #{type.capitalize} Field",
        'string',
        type
      )
      
      assert_not_nil field_id, "Failed to create #{type} custom field"
      field = CustomField.find(field_id)
      assert_instance_of klass, field
    end
  end

  test "should return nil for invalid field format" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Invalid Field',
      'invalid_format',
      'issue'
    )
    
    assert_nil field_id
  end

  test "should return nil for invalid customized type" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Invalid Type',
      'string',
      'invalid_type'
    )
    
    assert_nil field_id
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # update_custom_field tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should update custom field name" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Original Name',
      'string',
      'issue'
    )
    
    success = HrzLib::CustomFieldHelper.update_custom_field(
      field_id,
      name: 'Test Updated Name'
    )
    
    assert success
    field = CustomField.find(field_id)
    assert_equal 'Test Updated Name', field.name
  end

  test "should update custom field description" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Field',
      'string',
      'issue'
    )
    
    success = HrzLib::CustomFieldHelper.update_custom_field(
      field_id,
      description: 'Updated description'
    )
    
    assert success
    field = CustomField.find(field_id)
    assert_equal 'Updated description', field.description
  end

  test "should update custom field required status" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Field',
      'string',
      'issue',
      is_required: false
    )
    
    success = HrzLib::CustomFieldHelper.update_custom_field(
      field_id,
      is_required: true
    )
    
    assert success
    field = CustomField.find(field_id)
    assert field.is_required
  end

  test "should update list field possible values" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test List',
      'list',
      'issue',
      possible_values: ['A', 'B', 'C']
    )
    
    success = HrzLib::CustomFieldHelper.update_custom_field(
      field_id,
      possible_values: ['A', 'B', 'C', 'D', 'E']
    )
    
    assert success
    field = CustomField.find(field_id)
    assert_equal ['A', 'B', 'C', 'D', 'E'], field.possible_values
  end

  test "should return false for nonexistent custom field" do
    success = HrzLib::CustomFieldHelper.update_custom_field(
      99999,
      name: 'Test'
    )
    
    assert_not success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # delete_custom_field tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should delete custom field" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Delete Field',
      'string',
      'issue'
    )
    
    success = HrzLib::CustomFieldHelper.delete_custom_field(field_id)
    
    assert success
    assert_nil CustomField.find_by(id: field_id)
  end

  test "should return false when deleting nonexistent field" do
    success = HrzLib::CustomFieldHelper.delete_custom_field(99999)
    
    assert_not success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # get_custom_field tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should get custom field details" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Get Field',
      'string',
      'issue',
      description: 'Test description',
      is_required: true
    )
    
    field = HrzLib::CustomFieldHelper.get_custom_field(field_id)
    
    assert_not_nil field
    assert_equal 'Test Get Field', field[:name]
    assert_equal 'string', field[:field_format]
    assert_equal 'issue', field[:customized_type]
    assert_equal 'Test description', field[:description]
    assert field[:is_required]
  end

  test "should return nil for nonexistent field" do
    field = HrzLib::CustomFieldHelper.get_custom_field(99999)
    
    assert_nil field
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # list_custom_fields tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should list all custom fields" do
    HrzLib::CustomFieldHelper.create_custom_field('Test List 1', 'string', 'issue')
    HrzLib::CustomFieldHelper.create_custom_field('Test List 2', 'string', 'project')
    
    fields = HrzLib::CustomFieldHelper.list_custom_fields
    
    assert_not_nil fields
    assert fields.length >= 2
  end

  test "should list custom fields filtered by type" do
    HrzLib::CustomFieldHelper.create_custom_field('Test Issue Field', 'string', 'issue')
    HrzLib::CustomFieldHelper.create_custom_field('Test Project Field', 'string', 'project')
    
    issue_fields = HrzLib::CustomFieldHelper.list_custom_fields('issue')
    
    assert_not_nil issue_fields
    assert issue_fields.all? { |f| f[:customized_type] == 'issue' }
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # Computed custom field tests (require Computed Custom Field plugin)
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should create computed custom field if plugin available" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    field_id = HrzLib::CustomFieldHelper.create_computed_field(
      'Test Computed Field',
      'float',
      'issue',
      'cfs[1] * cfs[2]',
      description: 'Test computation'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'cfs[1] * cfs[2]', field.formula
  end

  test "should warn if creating computed field without plugin" do
    skip "Test only relevant when plugin is NOT installed" if CustomField.new.respond_to?(:formula=)
    
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Computed Without Plugin',
      'float',
      'issue',
      is_computed: true,
      formula: 'cfs[1] * cfs[2]'
    )
    
    # Should still create field but without formula
    assert_not_nil field_id
  end

  test "should validate formula if plugin available" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    result = HrzLib::CustomFieldHelper.validate_formula('cfs[1] * cfs[2]', 'issue')
    
    assert result[:valid]
    assert_nil result[:error]
  end

  test "should detect invalid formula if plugin available" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    result = HrzLib::CustomFieldHelper.validate_formula('invalid ruby code {', 'issue')
    
    assert_not result[:valid]
    assert_not_nil result[:error]
  end

  test "should get formula fields if plugin available" do
    skip "Computed Custom Field plugin not installed" unless CustomField.new.respond_to?(:formula=)
    
    # Create some custom fields
    HrzLib::CustomFieldHelper.create_custom_field('Test CF 1', 'int', 'issue')
    HrzLib::CustomFieldHelper.create_custom_field('Test CF 2', 'float', 'issue')
    
    fields = HrzLib::CustomFieldHelper.get_formula_fields('issue')
    
    assert_not_nil fields
    assert fields.key?(:custom_fields)
    assert fields.key?(:attributes)
    assert fields[:custom_fields].length >= 2
    assert_not_empty fields[:attributes]
  end

  test "should return error when validating without plugin" do
    skip "Test only relevant when plugin is NOT installed" if CustomField.new.respond_to?(:formula=)
    
    result = HrzLib::CustomFieldHelper.validate_formula('cfs[1] * cfs[2]', 'issue')
    
    assert_not result[:valid]
    assert_equal "Computed Custom Field plugin not installed", result[:error]
  end

  test "should return empty formula fields without plugin" do
    skip "Test only relevant when plugin is NOT installed" if CustomField.new.respond_to?(:formula=)
    
    fields = HrzLib::CustomFieldHelper.get_formula_fields('issue')
    
    # Should still return structure but might not have formula-specific data
    assert_not_nil fields
    assert fields.key?(:custom_fields)
    assert fields.key?(:attributes)
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # Edge cases and error handling
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should handle special characters in field name" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Field (Special) & More!',
      'string',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'Test Field (Special) & More!', field.name
  end

  test "should handle empty description" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Empty Desc',
      'string',
      'issue',
      description: ''
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal '', field.description
  end

  test "should handle nil in optional parameters" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Nil Params',
      'string',
      'issue',
      description: nil,
      default_value: nil
    )
    
    assert_not_nil field_id
  end
end
