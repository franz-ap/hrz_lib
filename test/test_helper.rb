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
# Purpose: Test helper configuration for hrz_lib plugin tests.
#
# * Loads the Redmine test helper.
# * Defines some test utilities (create_test_project, create_test_user, etc.)
# * Used by all other tests
#
# Pre-requisites:
#   Grant the application user rights in the test database.
#   You may have to do something like this:
#       GRANT ALL PRIVILEGES ON `redm_test`.* TO `redmine_appl`@`172.%`;
#       FLUSH PRIVILEGES;
#
# How to run the tests:
# * All tests for this plugin
#   bundle exec rake redmine:plugins:test NAME=hrz_lib
# * Only unit tests
#   bundle exec rake redmine:plugins:test:units NAME=hrz_lib
# * Only functional tests
#   bundle exec rake redmine:plugins:test:functionals NAME=hrz_lib
# * Test a single file:
#   bundle exec ruby -Itest test/unit/hrz_lib/issue_helper_test.rb
#
# Test-Coverage:
# * Positive cases: Normal use of all functions
# * Negative cases: error handling (non-existing IDs, invalid parameters)
# * Edge cases: empty values, special characters, nil Parameters
# * Access rights: Admin vs. non-admin access
# * API formats: JSON und XML
# * Plugin dependencies: Tests with/without Computed Custom Field plugin
#
# Features:
# * Conditional tests: Skipping tests for Computed Custom Fields when the plugin is not installed.
# * Fixtures: Uses standard Redmine fixtures + own Custom Field fixtures
# * Cleanup: Automatic, after tests
# * Helper Methods: re-usable test methods, defined in here.



# Load the Redmine test helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

# Additional test utilities for hrz_lib plugin
module HrzLibTestHelper
  # Creates a test project
  def create_test_project(identifier = 'test-project')
    Project.create!(
      name: "Test Project #{identifier}",
      identifier: identifier,
      is_public: true,
      enabled_module_names: ['issue_tracking', 'time_tracking']
    )
  end

  # Creates a test user
  def create_test_user(login = 'testuser')
    User.create!(
      login: login,
      firstname: 'Test',
      lastname: 'User',
      mail: "#{login}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      status: User::STATUS_ACTIVE
    )
  end

  # Creates a test tracker
  def create_test_tracker(name = 'Bug')
    Tracker.create!(
      name: name,
      default_status_id: IssueStatus.default.id,
      position: 1
    )
  end

  # Creates a test issue
  def create_test_issue(project, attributes = {})
    Issue.create!(
      project: project,
      tracker: project.trackers.first || create_test_tracker,
      author: User.current || User.find(1),
      subject: attributes[:subject] || 'Test Issue',
      description: attributes[:description] || 'Test Description',
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
  end

  # Creates a test custom field
  def create_test_custom_field(name = 'Test Field', field_format = 'string', customized_type = 'issue')
    klass = case customized_type
            when 'issue' then IssueCustomField
            when 'project' then ProjectCustomField
            when 'user' then UserCustomField
            else CustomField
            end
    
    klass.create!(
      name: name,
      field_format: field_format,
      is_required: false,
      is_for_all: true
    )
  end

  # Sets User.current for the duration of a block
  def with_user(user)
    original_user = User.current
    User.current = user
    yield
  ensure
    User.current = original_user
  end
end

# Include the helper in all test cases
class ActiveSupport::TestCase
  include HrzLibTestHelper
end
