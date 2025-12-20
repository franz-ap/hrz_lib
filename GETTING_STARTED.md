# Getting Started with HRZ Lib Plugin

This guide will help you install and use the HRZ Lib plugin in your Redmine plugins.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Verification](#verification)
- [Your First Plugin Using HRZ Lib](#your-first-plugin-using-hrz-lib)
- [Understanding User.current](#understanding-usercurrent)
- [Working with Custom Fields](#working-with-custom-fields)
- [Complete Example: Task Management Plugin](#complete-example-task-management-plugin)
- [Testing Your Plugin](#testing-your-plugin)
- [Common Issues and Solutions](#common-issues-and-solutions)
- [Best Practices](#best-practices)
- [Getting Help](#getting-help)

---

## Prerequisites

Before installing HRZ Lib, ensure you have:

- **Redmine**: Version 6.1.0 or higher. If you have that, then most likely the remaining prerequisites will also be available.
- **Ruby**: Version 3.0 or higher (check with `ruby -v`)
- **Rails**: Version 7.0 or higher (bundled with Redmine)
- **Database**: PostgreSQL, MySQL, or SQLite
- **Administrator access** to your Redmine installation

---

## Installation

### Step 1: Navigate to Plugins Directory

```bash
cd /path/to/redmine
cd plugins
```

### Step 2: Clone the Repository

```bash
# If you have the repository URL:
git clone https://github.com/your-org/hrz_lib.git hrz_lib

# Or copy the plugin directory if you received it as a package:
cp -r /path/to/hrz_lib ./
```

### Step 3: Install Dependencies

```bash
cd ..  # Back to Redmine root
bundle install
```

### Step 4: Run Migrations

```bash
# Development environment
RAILS_ENV=development bundle exec rake redmine:plugins:migrate

# Production environment
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
```

### Step 5: Restart Redmine

```bash
# If using Passenger:
touch tmp/restart.txt

# If using Puma/Unicorn:
sudo systemctl restart redmine

# If using WEBrick (development):
# Stop with Ctrl+C and restart with:
bundle exec rails server -e development
```

---

## Verification

### Verify Installation in Redmine UI

1. Log in as administrator
2. Go to **Administration → Plugins**
3. You should see **HRZ Lib** listed with version number

### Verify Installation via Rails Console

```bash
cd /path/to/redmine
RAILS_ENV=production bundle exec rails console
```

```ruby
# Check if plugin is loaded
Redmine::Plugin.find(:hrz_lib)
# Should return plugin information

# Check if helper modules are available
HrzLib::IssueHelper
# Should return: HrzLib::IssueHelper

HrzLib::CustomFieldHelper
# Should return: HrzLib::CustomFieldHelper

# Exit console
exit
```

---

## Your First Plugin Using HRZ Lib

Let's create a simple plugin that creates issues using HRZ Lib.

### Step 1: Create Plugin Structure

```bash
cd plugins
mkdir my_task_creator
cd my_task_creator
mkdir -p lib/tasks
touch init.rb
touch lib/my_task_creator.rb
```

### Step 2: Create init.rb

```ruby
# plugins/my_task_creator/init.rb

require 'redmine'

Redmine::Plugin.register :my_task_creator do
  name 'My Task Creator'
  author 'Your Name'
  description 'Example plugin using HRZ Lib'
  version '0.1.0'
  url 'https://example.com'
  author_url 'https://example.com'
  
  # IMPORTANT: Declare dependency on hrz_lib
  requires_redmine_plugin :hrz_lib, version_or_higher: '0.4.0'
end

# Load HRZ Lib helper modules
require 'hrz_lib/issue_helper'
require 'hrz_lib/custom_field_helper'

# Load our plugin module
require_relative 'lib/my_task_creator'
```

### Step 3: Create Plugin Module

```ruby
# plugins/my_task_creator/lib/my_task_creator.rb

module MyTaskCreator
  
  # Creates a simple task in a project
  #
  # @param project_identifier [String] Project identifier
  # @param task_title [String] Task title
  # @param task_description [String] Task description
  # @param assignee_id [Integer, nil] User ID to assign task to
  # @return [Integer, nil] Issue ID or nil on error
  def self.create_task(project_identifier, task_title, task_description, assignee_id = nil)
    begin
      # Create the issue using HRZ Lib
      issue_id = HrzLib::IssueHelper.mk_issue(
        project_identifier,
        task_title,
        task_description,
        assignee_id,
        [],  # No watchers for now
        tracker_id: 1,  # Assuming tracker ID 1 exists (usually "Bug" or "Task")
        priority_id: 2  # Assuming priority ID 2 exists (usually "Normal")
      )
      
      if issue_id
        Rails.logger.info "MyTaskCreator: Created issue ##{issue_id}"
        return issue_id
      else
        Rails.logger.error "MyTaskCreator: Failed to create issue"
        return nil
      end
      
    rescue => e
      Rails.logger.error "MyTaskCreator: Exception creating issue: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end
  
end
```

### Step 4: Test Your Plugin

Restart Redmine and test in Rails console:

```ruby
# In Rails console
RAILS_ENV=production bundle exec rails console

# Set current user (IMPORTANT!)
User.current = User.find_by(login: 'admin')

# Test creating a task
issue_id = MyTaskCreator.create_task(
  'my-project',
  'Test Task',
  'This is a test task created via my plugin'
)

puts "Created issue: ##{issue_id}"

# Verify the issue was created
issue = Issue.find(issue_id)
puts issue.subject
# Should output: "Test Task"

exit
```

---

## Understanding User.current

**CRITICAL CONCEPT**: Redmine uses `User.current` to track who is performing actions. Many operations will fail if `User.current` is not set.

### What is User.current?

`User.current` is a thread-local variable that stores the currently active user. It's used for:
- Determining permissions
- Setting `created_by` and `updated_by` fields
- Audit logging
- Access control

### When Must You Set User.current?

**Always set it when:**
- Running code in Rails console
- Executing rake tasks
- Running background jobs
- Using cron jobs
- Calling HRZ Lib methods outside of a web request

**Not needed when:**
- Inside controller actions (Redmine sets it automatically)
- In model callbacks during web requests

### How to Set User.current

```ruby
# Find a user
user = User.find_by(login: 'admin')
# or
user = User.find(5)

# Set as current user
User.current = user

# Now you can use HRZ Lib methods
issue_id = HrzLib::IssueHelper.mk_issue(...)

# IMPORTANT: Always reset after use in shared contexts
User.current = nil
```

### Safe Pattern: Ensure Cleanup

```ruby
def my_method
  original_user = User.current
  User.current = User.find_by(login: 'admin')
  
  begin
    # Your code here
    issue_id = HrzLib::IssueHelper.mk_issue(...)
  ensure
    # Always restore original user
    User.current = original_user
  end
end
```

### In Rake Tasks

```ruby
# lib/tasks/my_task.rake
namespace :my_plugin do
  desc "Create daily reports"
  task create_reports: :environment do
    # Set user for the task
    User.current = User.find_by(login: 'admin')
    
    begin
      # Your code using HRZ Lib
      issue_id = HrzLib::IssueHelper.mk_issue(...)
      puts "Created issue ##{issue_id}"
    ensure
      User.current = nil
    end
  end
end
```

---

## Working with Custom Fields

### Check if Custom Field Exists

Before creating issues with custom fields, check if the field exists:

```ruby
# Find a custom field by name
field = CustomField.find_by(name: 'Customer Name')

if field
  puts "Field exists with ID: #{field.id}"
else
  # Create it using HRZ Lib
  field_id = HrzLib::CustomFieldHelper.create_custom_field(
    'Customer Name',
    'string',
    'issue',
    is_required: true,
    max_length: 100
  )
  puts "Created field with ID: #{field_id}"
end
```

### Create Issue with Custom Field

```ruby
# Ensure field exists
field = CustomField.find_by(name: 'Customer Name')
field_id = field ? field.id : HrzLib::CustomFieldHelper.create_custom_field(...)

# Create issue with custom field value
issue_id = HrzLib::IssueHelper.mk_issue(
  'my-project',
  'Customer Request',
  'Handle customer inquiry',
  nil,
  [],
  custom_fields: {
    field_id => 'Acme Corporation'
  }
)
```

### Update Custom Field Value

```ruby
issue_id = 42
field_id = 1

HrzLib::IssueHelper.update_issue(
  issue_id,
  custom_fields: {
    field_id => 'New Value'
  },
  notes: 'Updated customer name'
)
```

---

## Complete Example: Task Management Plugin

Here's a complete, production-ready example plugin:

### Directory Structure

```
plugins/task_manager/
├── init.rb
├── app/
│   └── controllers/
│       └── task_manager_controller.rb
├── config/
│   └── routes.rb
└── lib/
    └── task_manager/
        └── task_service.rb
```

### init.rb

```ruby
# plugins/task_manager/init.rb

require 'redmine'

Redmine::Plugin.register :task_manager do
  name 'Task Manager Plugin'
  author 'Your Name'
  description 'Advanced task management using HRZ Lib'
  version '1.0.0'
  
  requires_redmine_plugin :hrz_lib, version_or_higher: '0.4.0'
  
  menu :project_menu, :task_manager, 
       { controller: 'task_manager', action: 'index' },
       caption: 'Tasks',
       after: :activity,
       param: :project_id
end

require 'hrz_lib/issue_helper'
require 'hrz_lib/custom_field_helper'
```

### routes.rb

```ruby
# plugins/task_manager/config/routes.rb

RedmineApp::Application.routes.draw do
  resources :projects do
    resources :task_manager, only: [:index, :create]
  end
end
```

### task_service.rb

```ruby
# plugins/task_manager/lib/task_manager/task_service.rb

module TaskManager
  class TaskService
    
    # Initialize custom fields (run once during setup)
    def self.setup_custom_fields
      ensure_field_exists('Task Priority', 'list', ['Low', 'Medium', 'High'])
      ensure_field_exists('Estimated Cost', 'float')
      ensure_field_exists('Customer Name', 'string')
    end
    
    # Create a managed task with all features
    def self.create_managed_task(project_id, options = {})
      # Ensure custom fields exist
      priority_field = CustomField.find_by(name: 'Task Priority')
      cost_field = CustomField.find_by(name: 'Estimated Cost')
      customer_field = CustomField.find_by(name: 'Customer Name')
      
      # Prepare custom fields hash
      custom_fields = {}
      custom_fields[priority_field.id] = options[:priority] if priority_field && options[:priority]
      custom_fields[cost_field.id] = options[:cost] if cost_field && options[:cost]
      custom_fields[customer_field.id] = options[:customer] if customer_field && options[:customer]
      
      # Create the issue
      issue_id = HrzLib::IssueHelper.mk_issue(
        project_id,
        options[:subject] || 'New Task',
        options[:description] || '',
        options[:assignee_id],
        options[:watcher_ids] || [],
        tracker_id: options[:tracker_id] || 1,
        priority_id: options[:priority_id] || 2,
        due_date: options[:due_date],
        estimated_hours: options[:estimated_hours],
        custom_fields: custom_fields
      )
      
      return nil unless issue_id
      
      # Attach file if provided
      if options[:file_path] && File.exist?(options[:file_path])
        HrzLib::IssueHelper.attach_file(
          issue_id,
          options[:file_path],
          description: options[:file_description]
        )
      end
      
      # Add initial comment if provided
      if options[:initial_comment]
        HrzLib::IssueHelper.add_comment(
          issue_id,
          options[:initial_comment]
        )
      end
      
      # Log time if provided
      if options[:initial_hours]
        HrzLib::IssueHelper.create_time_entry(
          issue_id,
          options[:initial_hours],
          activity_id: options[:activity_id] || TimeEntryActivity.first.id,
          comments: options[:time_comment] || 'Initial time entry'
        )
      end
      
      Rails.logger.info "TaskManager: Created managed task ##{issue_id}"
      issue_id
    end
    
    private
    
    def self.ensure_field_exists(name, format, possible_values = nil)
      field = CustomField.find_by(name: name)
      return field if field
      
      options = {
        is_required: false,
        is_for_all: true
      }
      options[:possible_values] = possible_values if possible_values
      
      HrzLib::CustomFieldHelper.create_custom_field(
        name,
        format,
        'issue',
        options
      )
    end
    
  end
end
```

### task_manager_controller.rb

```ruby
# plugins/task_manager/app/controllers/task_manager_controller.rb

class TaskManagerController < ApplicationController
  before_action :find_project
  before_action :authorize
  
  def index
    @issues = @project.issues.order('created_on DESC').limit(20)
  end
  
  def create
    # User.current is already set by Redmine in controller actions
    
    issue_id = TaskManager::TaskService.create_managed_task(
      @project.id,
      subject: params[:subject],
      description: params[:description],
      assignee_id: params[:assignee_id],
      watcher_ids: params[:watcher_ids],
      priority: params[:task_priority],
      cost: params[:estimated_cost],
      customer: params[:customer_name],
      due_date: params[:due_date],
      estimated_hours: params[:estimated_hours],
      initial_comment: params[:initial_comment],
      initial_hours: params[:initial_hours]
    )
    
    if issue_id
      flash[:notice] = "Task ##{issue_id} created successfully"
      redirect_to project_task_manager_index_path(@project)
    else
      flash[:error] = "Failed to create task. Check logs for details."
      redirect_to project_task_manager_index_path(@project)
    end
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
```

### Usage Example

```ruby
# In Rails console or rake task:
User.current = User.find_by(login: 'admin')

# Setup (run once)
TaskManager::TaskService.setup_custom_fields

# Create a managed task
issue_id = TaskManager::TaskService.create_managed_task(
  'my-project',
  subject: 'Implement new feature',
  description: 'Detailed description here',
  assignee_id: 5,
  watcher_ids: [3, 7],
  priority: 'High',
  cost: 5000.00,
  customer: 'Acme Corp',
  due_date: '2025-12-31',
  estimated_hours: 40,
  initial_comment: 'Started working on this task',
  initial_hours: 2.5,
  time_comment: 'Initial planning'
)

puts "Created task: ##{issue_id}"
```

---

## Testing Your Plugin

### Create a Test File

```ruby
# plugins/my_plugin/test/unit/my_plugin_test.rb

require File.expand_path('../../test_helper', __FILE__)

class MyPluginTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses
  
  def setup
    @user = User.find(1)
    User.current = @user
    @project = Project.find(1)
  end
  
  def teardown
    User.current = nil
  end
  
  test "should create issue using hrz_lib" do
    issue_id = HrzLib::IssueHelper.mk_issue(
      @project.id,
      'Test Issue',
      'Test Description'
    )
    
    assert_not_nil issue_id
    issue = Issue.find(issue_id)
    assert_equal 'Test Issue', issue.subject
  end
  
  test "should create custom field using hrz_lib" do
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Test Field',
      'string',
      'issue'
    )
    
    assert_not_nil field_id
    field = CustomField.find(field_id)
    assert_equal 'Test Field', field.name
  end
end
```

### Run Tests

```bash
cd /path/to/redmine

# Run all tests for your plugin
bundle exec rake redmine:plugins:test NAME=my_plugin

# Run specific test file
bundle exec ruby -I test plugins/my_plugin/test/unit/my_plugin_test.rb
```

---

## Common Issues and Solutions

### Issue 1: "Plugin hrz_lib not found"

**Symptom:**
```
Plugin dependency not met: hrz_lib (version_or_higher: 0.4.0) is required
```

**Solution:**
1. Verify hrz_lib is in `plugins/hrz_lib/` directory
2. Check `plugins/hrz_lib/init.rb` exists
3. Restart Redmine completely
4. Check Administration → Plugins to see if hrz_lib is listed

### Issue 2: "Issue creation returns nil"

**Symptom:**
```ruby
issue_id = HrzLib::IssueHelper.mk_issue(...)
# issue_id is nil
```

**Solutions:**

**A) Check User.current:**
```ruby
# This is the most common cause!
puts User.current.inspect
# If it shows nil, set it:
User.current = User.find_by(login: 'admin')
```

**B) Check Rails logs:**
```bash
tail -f log/production.log
# or
tail -f log/development.log
```

**C) Verify project exists:**
```ruby
Project.find_by(identifier: 'my-project')
# Should not return nil
```

**D) Verify tracker exists:**
```ruby
Tracker.find(1)
# Should not raise error
```

### Issue 3: "Custom field creation fails"

**Symptom:**
Custom field creation returns nil

**Solutions:**

**A) Check if field already exists:**
```ruby
CustomField.find_by(name: 'My Field')
# If it exists, use its ID instead of creating new one
```

**B) Verify you're admin:**
```ruby
User.current.admin?
# Should return true
```

**C) Check field format is valid:**
```ruby
# Valid formats: string, text, int, float, date, bool, list, user, version, link, attachment
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'My Field',
  'string',  # Make sure this is valid!
  'issue'
)
```

### Issue 4: "LoadError: cannot load such file -- hrz_lib/issue_helper"

**Symptom:**
```
LoadError: cannot load such file -- hrz_lib/issue_helper
```

**Solution:**
```ruby
# In your init.rb, make sure this comes AFTER requires_redmine_plugin:

Redmine::Plugin.register :my_plugin do
  # ...
  requires_redmine_plugin :hrz_lib, version_or_higher: '0.4.0'
end

# NOW you can require the helpers:
require 'hrz_lib/issue_helper'
require 'hrz_lib/custom_field_helper'
```

### Issue 5: "Permission denied" errors

**Symptom:**
Operations fail even though User.current is set

**Solution:**
```ruby
# Check user has required permissions
user = User.current
project = Project.find('my-project')

# Check if user is member of project
member = project.members.find_by(user_id: user.id)
puts "Is member: #{member.present?}"

# Check roles
if member
  member.roles.each do |role|
    puts "Role: #{role.name}"
    puts "Can add issues: #{role.permissions.include?(:add_issues)}"
  end
end

# If user is not a member, add them:
Member.create!(
  user: user,
  project: project,
  roles: [Role.find_by(name: 'Manager')]
)
```

### Issue 6: "Circular dependency" errors

**Symptom:**
```
Circular dependency detected while autoloading constant MyPlugin
```

**Solution:**
Don't require your own plugin files in init.rb if they're in app/ directory. Rails autoloads those.

```ruby
# WRONG:
require_relative 'app/controllers/my_controller'

# RIGHT - let Rails autoload:
# (just don't require it at all)
```

---

## Best Practices

### 1. Always Check Return Values

```ruby
# GOOD
issue_id = HrzLib::IssueHelper.mk_issue(...)
if issue_id
  puts "Success: ##{issue_id}"
else
  Rails.logger.error "Failed to create issue"
  # Handle error appropriately
end

# BAD
issue_id = HrzLib::IssueHelper.mk_issue(...)
Issue.find(issue_id)  # Might crash if issue_id is nil!
```

### 2. Use Transactions for Multiple Operations

```ruby
ActiveRecord::Base.transaction do
  # Create custom field
  field_id = HrzLib::CustomFieldHelper.create_custom_field(...)
  raise "Field creation failed" unless field_id
  
  # Create issue with that field
  issue_id = HrzLib::IssueHelper.mk_issue(
    ...,
    custom_fields: {field_id => 'value'}
  )
  raise "Issue creation failed" unless issue_id
  
  # If any operation fails, everything rolls back
end
```

### 3. Cache Custom Field IDs

```ruby
# INEFFICIENT - looks up field every time
def create_task
  field = CustomField.find_by(name: 'Customer Name')
  HrzLib::IssueHelper.mk_issue(..., custom_fields: {field.id => 'value'})
end

# BETTER - cache field IDs
class MyService
  def initialize
    @customer_field_id = CustomField.find_by(name: 'Customer Name')&.id
    @priority_field_id = CustomField.find_by(name: 'Priority')&.id
  end
  
  def create_task
    HrzLib::IssueHelper.mk_issue(
      ...,
      custom_fields: {
        @customer_field_id => 'value',
        @priority_field_id => 'High'
      }
    )
  end
end
```

### 4. Log Important Operations

```ruby
def create_task(project_id, subject)
  Rails.logger.info "Creating task in project #{project_id}: #{subject}"
  
  issue_id = HrzLib::IssueHelper.mk_issue(project_id, subject, ...)
  
  if issue_id
    Rails.logger.info "Successfully created issue ##{issue_id}"
  else
    Rails.logger.error "Failed to create issue in project #{project_id}"
  end
  
  issue_id
end
```

### 5. Wrap External Calls in Begin/Rescue

```ruby
def safe_create_issue(project_id, subject)
  begin
    issue_id = HrzLib::IssueHelper.mk_issue(project_id, subject, ...)
    return issue_id
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Project not found: #{e.message}"
    return nil
  rescue => e
    Rails.logger.error "Unexpected error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    return nil
  end
end
```

---

## Getting Help

### Check Logs First

```bash
# Development
tail -f log/development.log

# Production
tail -f log/production.log

# Search for HRZ Lib messages
grep "HRZ Lib" log/production.log
```

### Debug in Rails Console

```bash
RAILS_ENV=production bundle exec rails console
```

```ruby
# Enable SQL logging
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Set user
User.current = User.find(1)

# Try operation
issue_id = HrzLib::IssueHelper.mk_issue('test', 'Test', 'Test')

# Check result
if issue_id.nil?
  puts "Failed - check log output above"
else
  puts "Success: ##{issue_id}"
end
```

### Enable Debug Logging

```ruby
# In config/environment.rb or config/environments/development.rb
Rails.logger.level = :debug
```

### Community Resources

- **Redmine Forums**: https://www.redmine.org/projects/redmine/boards
- **Stack Overflow**: Tag questions with `redmine` and `redmine-plugin`
- **GitHub Issues**: Report bugs in hrz_lib repository

### Report Issues

When reporting issues, include:
1. Redmine version: `Redmine::VERSION`
2. Ruby version: `ruby -v`
3. HRZ Lib version: Check Administration → Plugins
4. Relevant log entries
5. Steps to reproduce
6. Expected vs actual behavior

---

## Next Steps

Now that you understand the basics:

1. **Read the full README.md** for complete API reference
2. **Study the test files** in `test/` directory for more examples
3. **Experiment in Rails console** before writing code
4. **Start small** - create simple plugins first
5. **Use version control** - commit working code frequently

Happy coding! 🚀
