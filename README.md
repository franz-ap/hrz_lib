# HRZ Lib Plugin for Redmine

This Redmine plugin provides helper methods/functions for other plugins and a REST API.

[![en](https://img.shields.io/badge/lang-en-green.svg)](https://github.com/franz-ap/hrz_lib/blob/main/README.md)
[![de](https://img.shields.io/badge/lang-de-grey.svg)](https://github.com/franz-ap/hrz_lib/blob/main/README.de.md)


## Overview

The HRZ Lib Plugin offers two main functional areas:

1. **Ruby Helper Modules** - Reusable functions for other plugins
2. **REST API** - HTTP-based interface for Custom Fields management

---

# Part 1: Ruby Helper Modules

## Usage in Other Plugins

### Define Plugin Dependency

To use the HRZ Lib helper modules in another plugin, add the following to your plugin's `init.rb`:

```ruby
Redmine::Plugin.register :my_plugin do
  name 'My Plugin'
  author 'Your Name'
  description 'Description'
  version '1.0.0'
  
  # Define dependency on hrz_lib
  requires_redmine_plugin :hrz_lib, version_or_higher: '0.4.0'
end

# Load helper modules
require 'hrz_lib/issue_helper'
require 'hrz_lib/custom_field_helper'
```

### Using Helper Methods

After loading the modules, the methods can be used directly:

```ruby
# In a controller, model, or helper of your plugin
class MyController < ApplicationController
  def my_action
    # Create issue
    issue_id = HrzLib::IssueHelper.mk_issue(
      'my-project',
      'New Issue',
      'Description'
    )
    
    # Create custom field
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'My Field',
      'string',
      'issue'
    )
  end
end
```

---

## IssueHelper Module

The `HrzLib::IssueHelper` module provides methods for managing Redmine issues.

### Issue Creation

#### `mk_issue(project_id, subject, description, assignee_id = nil, watcher_ids = [], options = {})`

Creates a new issue with the specified parameters.

**Parameters:**
- `project_id` - Project ID or identifier
- `subject` - Issue title
- `description` - Description text
- `assignee_id` - User ID of the assignee (optional)
- `watcher_ids` - Array of user IDs for watchers (optional)
- `options` - Hash with additional options:
  - `:tracker_id` - Tracker ID
  - `:status_id` - Status ID
  - `:priority_id` - Priority ID
  - `:category_id` - Category ID
  - `:fixed_version_id` - Target version ID
  - `:start_date` - Start date
  - `:due_date` - Due date
  - `:estimated_hours` - Estimated hours
  - `:done_ratio` - Completion percentage (0-100)
  - `:parent_issue_id` - Parent issue ID for subtasks
  - `:custom_fields` - Custom field values `{field_id => value}`

**Returns:** Issue ID or `nil` on error

**Examples:**

```ruby
# Simple issue
issue_id = HrzLib::IssueHelper.mk_issue(
  'my-project',
  'Fix bug',
  'The application crashes when...'
)

# With assignment and watchers
issue_id = HrzLib::IssueHelper.mk_issue(
  'my-project',
  'Implement feature',
  'Description',
  5,  # Assigned to User ID 5
  [3, 7, 12]  # Watcher User IDs
)

# With advanced options
issue_id = HrzLib::IssueHelper.mk_issue(
  'my-project',
  'Sprint task',
  'Description',
  nil,
  [],
  tracker_id: 2,
  priority_id: 4,
  due_date: '2025-12-31',
  estimated_hours: 8,
  custom_fields: {1 => 'Value1', 2 => 'Value2'}
)
```

### File Attachments

#### `attach_file(issue_id, file_path, options = {})`

Attaches a file to an existing issue.

**Parameters:**
- `issue_id` - Issue ID
- `file_path` - Full path to the file
- `options` - Hash with options:
  - `:filename` - Custom filename (default: original filename)
  - `:description` - Attachment description
  - `:author_id` - Author user ID (default: current user)
  - `:content_type` - MIME type (default: auto-detect)

**Returns:** Attachment ID or `nil` on error

**Examples:**

```ruby
# Simple attachment
attachment_id = HrzLib::IssueHelper.attach_file(
  42,
  '/tmp/screenshot.png'
)

# With options
attachment_id = HrzLib::IssueHelper.attach_file(
  42,
  '/tmp/report.pdf',
  filename: 'Monthly_Report.pdf',
  description: 'Financial report for November'
)
```

### Issue Relations

#### `create_relation(issue_from_id, issue_to_id, relation_type = 'relates', options = {})`

Creates a relation between two issues.

**Parameters:**
- `issue_from_id` - Source issue ID
- `issue_to_id` - Target issue ID
- `relation_type` - Relation type:
  - `'relates'` - Related to
  - `'duplicates'` - Duplicates
  - `'duplicated'` - Duplicated by
  - `'blocks'` - Blocks
  - `'blocked'` - Blocked by
  - `'precedes'` - Precedes
  - `'follows'` - Follows
  - `'copied_to'` - Copied to
  - `'copied_from'` - Copied from
- `options` - Hash with options:
  - `:delay` - Delay in days (only for 'precedes'/'follows')

**Returns:** Relation ID or `nil` on error

**Examples:**

```ruby
# Simple relation
relation_id = HrzLib::IssueHelper.create_relation(42, 43, 'relates')

# Blocking relation
relation_id = HrzLib::IssueHelper.create_relation(42, 43, 'blocks')

# Precedence with delay
relation_id = HrzLib::IssueHelper.create_relation(
  42, 43, 'precedes',
  delay: 5
)
```

### Issue Updates

#### `update_issue(issue_id, attributes = {}, options = {})`

Updates an existing issue.

**Parameters:**
- `issue_id` - Issue ID
- `attributes` - Hash of attributes to update (see `mk_issue`)
- `options` - Hash with options:
  - `:notes` - Journal note for the change
  - `:private_notes` - Whether notes are private (default: false)
  - `:author_id` - Author user ID

**Returns:** `true` on success, `false` on error

**Examples:**

```ruby
# Change title and assignee
success = HrzLib::IssueHelper.update_issue(
  42,
  subject: 'New Title',
  assigned_to_id: 5
)

# With note
success = HrzLib::IssueHelper.update_issue(
  42,
  {status_id: 3, done_ratio: 100},
  notes: 'Task completed'
)

# Update custom fields
success = HrzLib::IssueHelper.update_issue(
  42,
  custom_fields: {1 => 'New Value', 2 => 'Another Value'}
)
```

### Comments

#### `add_comment(issue_id, comment, options = {})`

Adds a comment to an issue.

**Parameters:**
- `issue_id` - Issue ID
- `comment` - Comment text
- `options` - Hash with options:
  - `:private` - Whether comment is private (default: false)
  - `:author_id` - Author user ID
  - `:attribute_changes` - Hash of attribute changes `{field => value}`

**Returns:** Journal ID or `nil` on error

**Examples:**

```ruby
# Simple comment
journal_id = HrzLib::IssueHelper.add_comment(
  42,
  'Progress update'
)

# Private comment
journal_id = HrzLib::IssueHelper.add_comment(
  42,
  'Internal note',
  private: true
)

# With attribute changes
journal_id = HrzLib::IssueHelper.add_comment(
  42,
  'Status changed to "In Progress"',
  attribute_changes: {status_id: 2}
)
```

### Watchers

#### `add_watcher(issue_id, user_id)`
Adds a watcher. Returns: `true`/`false`

#### `add_watchers(issue_id, user_ids)`
Adds multiple watchers. Returns: `{success: count, failed: [ids]}`

#### `remove_watcher(issue_id, user_id)`
Removes a watcher. Returns: `true`/`false`

#### `remove_watchers(issue_id, user_ids)`
Removes multiple watchers. Returns: `{success: count, failed: [ids]}`

#### `get_watchers(issue_id)`
List of all watchers. Returns: Array of `{id, login, name}` or `nil`

#### `is_watching?(issue_id, user_id)`
Checks if user is watching. Returns: `true`/`false`/`nil`

#### `set_watchers(issue_id, user_ids)`
Replaces all watchers. Returns: `true`/`false`

**Examples:**

```ruby
# Add single watcher
HrzLib::IssueHelper.add_watcher(42, 5)

# Add multiple watchers
result = HrzLib::IssueHelper.add_watchers(42, [3, 5, 7, 9])
puts "Success: #{result[:success]}, Failed: #{result[:failed]}"

# Remove watcher
HrzLib::IssueHelper.remove_watcher(42, 5)

# Get all watchers
watchers = HrzLib::IssueHelper.get_watchers(42)
watchers.each { |w| puts "#{w[:name]} (#{w[:login]})" }

# Check if user is watching
if HrzLib::IssueHelper.is_watching?(42, 5)
  puts "User is watching the issue"
end

# Replace watcher list
HrzLib::IssueHelper.set_watchers(42, [5, 6, 7])
```

### Search Related Issues and Subtasks

#### `find_related_with_subject(issue_id, search_text)`
Finds ID of related issue with search text in subject. Returns: Issue ID or `nil`

#### `has_related_with_subject?(issue_id, search_text)`
Checks if related issue with search text exists. Returns: `true`/`false`/`nil`

#### `find_subtask_with_subject(issue_id, search_text)`
Finds ID of subtask with search text in subject. Returns: Issue ID or `nil`

#### `has_subtask_with_subject?(issue_id, search_text)`
Checks if subtask with search text exists. Returns: `true`/`false`/`nil`

**Examples:**

```ruby
# Find related issue
related_id = HrzLib::IssueHelper.find_related_with_subject(42, 'deployment')
if related_id
  puts "Found: Issue ##{related_id}"
end

# Check if related issue exists
if HrzLib::IssueHelper.has_related_with_subject?(42, 'critical')
  puts "Critical related issue found"
end

# Find subtask
subtask_id = HrzLib::IssueHelper.find_subtask_with_subject(42, 'testing')

# Check if subtask exists
if HrzLib::IssueHelper.has_subtask_with_subject?(42, 'review')
  puts "Review subtask exists"
end
```

### Time Tracking

#### `create_time_entry(issue_id, hours, options = {})`

Creates a time entry for an issue.

**Parameters:**
- `issue_id` - Issue ID
- `hours` - Number of hours
- `options` - Hash with options:
  - `:activity_id` - Activity ID (required if multiple activities exist)
  - `:comments` - Comment/description
  - `:spent_on` - Date (default: today)
  - `:user_id` - User ID (default: current user)
  - `:custom_fields` - Custom field values

**Returns:** TimeEntry ID or `nil` on error

#### `update_time_entry(time_entry_id, attributes = {})`
Updates a time entry. Returns: `true`/`false`

#### `delete_time_entry(time_entry_id)`
Deletes a time entry. Returns: `true`/`false`

#### `get_time_entries(issue_id, options = {})`
List of all time entries for an issue. Returns: Array or `nil`

#### `get_total_hours(issue_id, options = {})`
Total hours for an issue. Returns: Float or `nil`

#### `get_time_entry_activities()`
List of available activities. Returns: Array or `nil`

#### `get_user_daily_hours(user_id, date = Date.today, options = {})`
Daily hours for a user. Returns: Hash with details or `nil`

#### `get_user_hours_range(user_id, from_date, to_date = nil, options = {})`
User hours in a date range. Returns: Hash or `nil`

**Examples:**

```ruby
# Create time entry
time_entry_id = HrzLib::IssueHelper.create_time_entry(
  42,
  2.5,
  activity_id: 9,
  comments: 'Development work'
)

# With specific date
time_entry_id = HrzLib::IssueHelper.create_time_entry(
  42,
  4.0,
  activity_id: 9,
  spent_on: '2025-12-10',
  user_id: 5
)

# Update time entry
HrzLib::IssueHelper.update_time_entry(123, hours: 3.5, comments: 'Updated')

# Delete time entry
HrzLib::IssueHelper.delete_time_entry(123)

# Get all time entries
entries = HrzLib::IssueHelper.get_time_entries(42)
entries.each { |e| puts "#{e[:spent_on]}: #{e[:hours]}h - #{e[:comments]}" }

# Get total hours
total = HrzLib::IssueHelper.get_total_hours(42)
puts "Total: #{total} hours"

# Get user's daily hours
result = HrzLib::IssueHelper.get_user_daily_hours(5)
puts "Today: #{result[:total_hours]}h in #{result[:entries_count]} entries"

# Get hours in date range
result = HrzLib::IssueHelper.get_user_hours_range(
  5,
  Date.today.beginning_of_week,
  Date.today.end_of_week
)
puts "This week: #{result[:total_hours]}h"

# With grouping by date
result = HrzLib::IssueHelper.get_user_hours_range(
  5,
  '2025-12-01',
  '2025-12-31',
  group_by_date: true
)
result[:by_date].each do |date, data|
  puts "#{date}: #{data[:hours]}h"
end
```

---

## CustomFieldHelper Module

The `HrzLib::CustomFieldHelper` module provides methods for managing custom fields.

### Create Custom Field

#### `create_custom_field(name, field_format, customized_type, options = {})`

Creates a new custom field.

**Parameters:**
- `name` - Custom field name
- `field_format` - Field type:
  - `'string'` - Single-line text
  - `'text'` - Multi-line text
  - `'int'` - Integer
  - `'float'` - Decimal number
  - `'date'` - Date
  - `'bool'` - Yes/No (checkbox)
  - `'list'` - Select list
  - `'user'` - User selection
  - `'version'` - Version selection
  - `'link'` - URL/Link
  - `'attachment'` - File attachment
- `customized_type` - Application scope:
  - `'issue'` - Ticket/Issue
  - `'project'` - Project
  - `'user'` - User
  - `'time_entry'` - Time entry
  - `'version'` - Version
  - `'document'` - Document
  - `'group'` - Group
- `options` - Hash with options:
  - `:description` - Description
  - `:is_required` - Required field (default: false)
  - `:is_for_all` - For all projects (default: true)
  - `:visible` - Visible (default: true)
  - `:searchable` - Searchable (default: false)
  - `:multiple` - Multiple selection for lists (default: false)
  - `:default_value` - Default value
  - `:regexp` - Validation regex
  - `:min_length` - Minimum length
  - `:max_length` - Maximum length
  - `:possible_values` - Array of possible values (for lists)
  - `:project_ids` - Array of project IDs
  - `:tracker_ids` - Array of tracker IDs (for issue custom fields)
  - `:role_ids` - Array of role IDs
  - `:formula` - Ruby formula for computed fields
  - `:is_computed` - Whether field is computed (default: false)

**Returns:** CustomField ID or `nil` on error

**Examples:**

```ruby
# Simple text field
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Customer Name',
  'string',
  'issue',
  is_required: true,
  max_length: 100
)

# Select list
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Priority Level',
  'list',
  'issue',
  possible_values: ['Low', 'Medium', 'High', 'Critical'],
  default_value: 'Medium'
)

# Multi-select list
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Tags',
  'list',
  'issue',
  multiple: true,
  possible_values: ['Bug', 'Feature', 'Enhancement', 'Docs']
)

# Date field
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Deadline',
  'date',
  'issue',
  is_required: true,
  description: 'Final delivery date'
)

# Numeric field with validation
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Estimated Cost',
  'float',
  'issue',
  description: 'Estimated cost in EUR'
)

# Only for specific projects
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Internal Reference',
  'string',
  'issue',
  is_for_all: false,
  project_ids: [1, 3, 5]
)

# Only for specific trackers
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Bug Category',
  'list',
  'issue',
  tracker_ids: [1],
  possible_values: ['UI', 'Backend', 'Database', 'API']
)
```

### Computed Custom Fields

Requires the [Computed Custom Field Plugin](https://github.com/annikoff/redmine_plugin_computed_custom_field).

#### `create_computed_field(name, field_format, customized_type, formula, options = {})`

Creates a computed custom field.

**Parameters:**
- `name`, `field_format`, `customized_type` - Same as `create_custom_field`
- `formula` - Ruby formula for calculation
  - Other custom fields: `cfs[field_id]`
  - Issue attributes: `self.attribute`
  - Ruby code: Any valid Ruby code
- `options` - Same as `create_custom_field`

**Returns:** CustomField ID or `nil` on error

**Examples:**

```ruby
# Simple multiplication
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Total Cost',
  'float',
  'issue',
  'cfs[1].to_f * cfs[2].to_f',
  description: 'Quantity (CF 1) * Unit Price (CF 2)'
)

# With conditions
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Discounted Price',
  'float',
  'issue',
  'if cfs[5].to_i > 100; cfs[5].to_f * 0.9; else; cfs[5].to_f; end',
  description: '10% discount for quantity > 100'
)

# With VAT
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Total with VAT',
  'float',
  'issue',
  '(cfs[1].to_f * cfs[2].to_f * 1.19).round(2)',
  description: 'Total Cost * 1.19 (19% VAT)'
)

# Using issue attributes
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Double Estimated Hours',
  'float',
  'issue',
  '(self.estimated_hours || 0) * 2'
)

# Date calculations
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Days Since Created',
  'int',
  'issue',
  '(Date.today - self.created_on.to_date).to_i if self.created_on'
)

# String concatenation
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Full Reference',
  'string',
  'issue',
  '"#{self.project.identifier}-#{self.id}"'
)

# With safe navigation operator
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Safe Calculation',
  'float',
  'issue',
  '(cfs[1].to_f * cfs[2].to_f).round(2) if cfs[1] && cfs[2]'
)
```

### Additional Custom Field Methods

#### `update_custom_field(custom_field_id, attributes = {})`
Updates a custom field. Returns: `true`/`false`

#### `delete_custom_field(custom_field_id)`
Deletes a custom field. Returns: `true`/`false`

#### `get_custom_field(custom_field_id)`
Gets custom field details. Returns: Hash or `nil`

#### `list_custom_fields(customized_type = nil)`
Lists all custom fields. Returns: Array

#### `validate_formula(formula, customized_type = 'issue')`
Validates a formula without creating a field. Returns: `{valid: bool, error: string}`

#### `get_formula_fields(customized_type)`
List of available fields for formulas. Returns: `{custom_fields: [...], attributes: [...]}`

**Examples:**

```ruby
# Update custom field
HrzLib::CustomFieldHelper.update_custom_field(
  field_id,
  description: 'Updated description',
  is_required: true
)

# Update formula (Computed Field)
HrzLib::CustomFieldHelper.update_custom_field(
  field_id,
  formula: 'cfs[1].to_f * cfs[2].to_f * 1.19'
)

# Get custom field
field = HrzLib::CustomFieldHelper.get_custom_field(field_id)
puts field[:name]
puts "Formula: #{field[:formula]}" if field[:formula]

# List all custom fields
fields = HrzLib::CustomFieldHelper.list_custom_fields('issue')
fields.each { |f| puts "#{f[:name]} (#{f[:field_format]})" }

# Delete custom field
HrzLib::CustomFieldHelper.delete_custom_field(field_id)

# Validate formula
result = HrzLib::CustomFieldHelper.validate_formula('cfs[1] * cfs[2]', 'issue')
if result[:valid]
  puts "Formula is valid"
else
  puts "Error: #{result[:error]}"
end

# Get available fields for formulas
fields = HrzLib::CustomFieldHelper.get_formula_fields('issue')
puts "Custom Fields:"
fields[:custom_fields].each { |cf| puts "  #{cf[:usage]} - #{cf[:name]}" }
puts "Attributes:"
fields[:attributes].each { |attr| puts "  #{attr[:usage]}" }
```

---

# Part 2: Custom Fields REST API

This documentation describes the REST API for managing custom fields in Redmine.

## Authentication

All API calls require authentication. Use either:
- HTTP Basic Auth
- API key in header: `X-Redmine-API-Key: your_api_key`
- API key as parameter: `?key=your_api_key`

**Note:** Only administrators can create, modify, or delete custom fields.

## Endpoints

### List All Custom Fields

```
GET /hrz_custom_fields.json
GET /hrz_custom_fields.xml
```

**Optional: Filter by type**
```
GET /hrz_custom_fields.json?customized_type=issue
```

**Example Response (JSON):**
```json
{
  "custom_fields": [
    {
      "id": 1,
      "name": "Customer Name",
      "field_format": "string",
      "customized_type": "issue",
      "is_required": true,
      "visible": true
    },
    {
      "id": 2,
      "name": "Priority Level",
      "field_format": "list",
      "customized_type": "issue",
      "is_required": false,
      "visible": true
    }
  ]
}
```

**cURL Example:**
```bash
curl -X GET \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  https://your-redmine.com/hrz_custom_fields.json
```

---

### Computed Custom Fields

**Requirement:** The [Computed Custom Field Plugin](https://github.com/annikoff/redmine_plugin_computed_custom_field) must be installed.

Computed Custom Fields enable automatic calculation of values based on other fields or issue attributes.

#### Formula Syntax

In formulas you can use:
- `cfs[cf_id]` - Value of another custom field (e.g. `cfs[1]`)
- `self.attribute` - Issue attributes (e.g. `self.estimated_hours`)
- Ruby code - Any valid Ruby code for calculations

#### Example 1: Simple Multiplication
```json
{
  "custom_field": {
    "name": "Total Cost",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "cfs[1].to_f * cfs[2].to_f",
    "description": "Quantity (CF 1) * Unit Price (CF 2)"
  }
}
```

**cURL:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "name": "Total Cost",
      "field_format": "float",
      "customized_type": "issue",
      "is_computed": true,
      "formula": "cfs[1].to_f * cfs[2].to_f"
    }
  }' \
  https://your-redmine.com/hrz_custom_fields.json
```

#### Example 2: With Conditions (if/else)
```json
{
  "custom_field": {
    "name": "Discounted Price",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "if cfs[5].to_i > 100; cfs[5].to_f * 0.9; else; cfs[5].to_f; end",
    "description": "10% discount for quantities over 100"
  }
}
```

---

### Validate Formula

```
POST /hrz_custom_fields/validate_formula.json
POST /hrz_custom_fields/validate_formula.xml
```

Validates a formula without creating a field.

**Parameters:**
- `formula`: Formula to validate
- `customized_type`: Type for context (optional, default: 'issue')

**Example:**
```json
{
  "formula": "cfs[1] * cfs[2]",
  "customized_type": "issue"
}
```

**cURL:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "formula": "cfs[1] * cfs[2]",
    "customized_type": "issue"
  }' \
  https://your-redmine.com/hrz_custom_fields/validate_formula.json
```

**Response for valid formula:**
```json
{
  "valid": true,
  "error": null
}
```

**Response for invalid formula:**
```json
{
  "valid": false,
  "error": "Formula contains syntax error"
}
```

---

### Get Available Fields for Formulas

```
GET /hrz_custom_fields/formula_fields.json?customized_type=issue
GET /hrz_custom_fields/formula_fields.xml?customized_type=issue
```

Returns all available custom fields and attributes that can be used in formulas.

**cURL:**
```bash
curl -X GET \
  -H "X-Redmine-API-Key: your_api_key" \
  https://your-redmine.com/hrz_custom_fields/formula_fields.json?customized_type=issue
```

**Response:**
```json
{
  "custom_fields": [
    {
      "id": 1,
      "name": "Quantity",
      "field_format": "int",
      "usage": "cfs[1]"
    },
    {
      "id": 2,
      "name": "Unit Price",
      "field_format": "float",
      "usage": "cfs[2]"
    }
  ],
  "attributes": [
    {"name": "id", "usage": "self.id"},
    {"name": "subject", "usage": "self.subject"},
    {"name": "estimated_hours", "usage": "self.estimated_hours"},
    {"name": "created_on", "usage": "self.created_on"}
  ]
}
```

---

### Custom Field Details

```
GET /hrz_custom_fields/:id.json
GET /hrz_custom_fields/:id.xml
```

**Example Response (JSON):**
```json
{
  "custom_field": {
    "id": 1,
    "name": "Customer Name",
    "description": "Name of the customer",
    "field_format": "string",
    "customized_type": "issue",
    "is_required": true,
    "is_for_all": true,
    "visible": true,
    "searchable": true,
    "multiple": false,
    "default_value": null,
    "possible_values": null,
    "regexp": null,
    "min_length": null,
    "max_length": 255
  }
}
```

**cURL Example:**
```bash
curl -X GET \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  
