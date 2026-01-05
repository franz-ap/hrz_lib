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
# Purpose: Helper module for creating and manipulating Redmine issues.

module HrzLib
  module IssueHelper

    # Creates a new Redmine issue with the specified parameters
    #
    # @param project_id [Integer, String] The ID or identifier of the project
    # @param b_subject [String] The title/subject of the new issue
    # @param b_desc [String] The description text of the issue
    # @param j_assignee [Integer, nil] The Redmine user ID of the assignee (nil = no assignee)
    # @param arr_watcher_ids [Array<Integer>, nil] Array of Redmine user IDs to be added as watchers (default: [])
    # @param options [Hash] Additional options for the issue
    # @option options [Integer] :tracker_id The tracker ID (required if project has multiple trackers)
    # @option options [Integer] :status_id The status ID (default: uses project's default status)
    # @option options [Integer] :priority_id The priority ID (default: uses default priority)
    # @option options [Integer] :category_id The category ID
    # @option options [Integer] :target_version_id The target version ID
    # @option options [Date, String] :start_date The start date
    # @option options [Date, String] :due_date The due date
    # @option options [Integer] :estimated_hours Estimated time in hours
    # @option options [Integer] :done_ratio Completion percentage (0-100)
    # @option options [Integer] :parent_issue_id Parent issue ID for subtasks
    # @option options [Hash] :custom_fields Custom field values, e.g., {1 => 'value1', 2 => 'value2'}
    # @option options [Integer] :author_id The author user ID (default: User.current)
    #
    # @return [Integer, nil] The ID of the newly created issue, or nil if creation failed
    #
    # @example Basic usage
    #   issue_id = HrzLib::IssueHelper.mk_issue(
    #     'myproject',
    #     'Fix critical bug',
    #     'The application crashes when...',
    #     5,
    #     [3, 7, 12]
    #   )
    #
    # @example With additional options
    #   issue_id = HrzLib::IssueHelper.mk_issue(
    #     'myproject',
    #     'New feature request',
    #     'We need to implement...',
    #     nil,
    #     [],
    #     { tracker_id: 2,
    #       priority_id: 4,
    #       due_date: '2025-12-31',
    #       custom_fields: {1 => 'High',
    #                       2 => 'External'
    #     }
    #   )
    #
    def self.mk_issue(project_id, b_subject, b_desc, j_assignee = nil, arr_watcher_ids = [], options = {})
      begin
        # Find the project
        project = Project.find(project_id)

        # Create the issue
        issue = Issue.new
        issue.project = project
        issue.subject = b_subject
        issue.description = b_desc
        issue.assigned_to_id = j_assignee
        issue.author = options[:author_id] ? User.find(options[:author_id]) : User.current

        # Set tracker (required field)
        if options[:tracker_id]
          issue.tracker_id = options[:tracker_id]
        else
          # Use first available tracker if not specified
          issue.tracker = project.trackers.first
        end

        # Set optional fields
        issue.status_id = options[:status_id] if options[:status_id]
        issue.priority_id = options[:priority_id] if options[:priority_id]
        issue.category_id = options[:category_id] if options[:category_id]
        issue.fixed_version_id = options[:target_version_id] if options[:target_version_id]
        issue.start_date = options[:start_date] if options[:start_date]
        issue.due_date = options[:due_date] if options[:due_date]
        issue.estimated_hours = options[:estimated_hours] if options[:estimated_hours]
        issue.done_ratio = options[:done_ratio] if options[:done_ratio]
        issue.parent_issue_id = options[:parent_issue_id] if options[:parent_issue_id]

        # Set custom fields if provided
        if options[:custom_fields] && options[:custom_fields].is_a?(Hash)
          options[:custom_fields].each do |field_id, value|
            issue.custom_field_values = {field_id => value}
          end
        end

        # Save the issue
        if issue.save
          # Add watchers if specified
          if arr_watcher_ids && arr_watcher_ids.is_a?(Array) && !arr_watcher_ids.empty?
            arr_watcher_ids.each do |user_id|
              begin
                user = User.find(user_id)
                Watcher.create(watchable: issue, user: user) if user
              rescue ActiveRecord::RecordNotFound
                HrzLogger.warning_msg "HRZ Lib: User with ID #{user_id} not found, skipping watcher."
              end
            end
          end

          HrzLogger.info_msg "HRZ Lib: Successfully created issue ##{issue.id} in project '#{project.identifier}'"
          return issue.id
        else
          HrzLogger.error_msg "HRZ Lib: Failed to create issue: #{issue.errors.full_messages.join(', ')}"
          return nil
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Project or resource not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error creating issue: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # mk_issue



    # Attaches a file to an existing issue
    #
    # @param issue_id [Integer] The ID of the issue to attach the file to
    # @param file_path [String] The full path to the file to be attached
    # @param options [Hash] Additional options for the attachment
    # @option options [String] :filename Custom filename (default: uses original filename)
    # @option options [String] :description Description of the attachment
    # @option options [Integer] :author_id The author user ID (default: User.current)
    # @option options [String] :content_type MIME type (default: auto-detected)
    #
    # @return [Integer, nil] The ID of the created attachment, or nil if attachment failed
    #
    # @example Basic usage
    #   attachment_id = HrzLib::IssueHelper.attach_file(
    #     42,
    #     '/tmp/screenshot.png'
    #   )
    #
    # @example With options
    #   attachment_id = HrzLib::IssueHelper.attach_file(
    #     42,
    #     '/tmp/report.pdf',
    #     filename: 'Monthly_Report.pdf',
    #     description: 'Financial report for November'
    #   )
    #
    def self.attach_file(issue_id, file_path, options = {})
      begin
        # Find the issue
        issue = Issue.find(issue_id)

        # Check if file exists
        unless File.exist?(file_path)
          HrzLogger.error_msg "HRZ Lib: File not found: #{file_path}"
          return nil
        end

        # Get filename
        filename = options[:filename] || File.basename(file_path)

        # Determine content type
        content_type = options[:content_type] || Redmine::MimeType.of(filename) || 'application/octet-stream'

        # Get author
        author = options[:author_id] ? User.find(options[:author_id]) : User.current

        # Read file content
        file_content = File.read(file_path, mode: 'rb')

        # Create attachment
        attachment = Attachment.new(
          container: issue,
          file: file_content,
          filename: filename,
          author: author,
          content_type: content_type,
          description: options[:description]
        )

        # For Redmine 6.x, we need to handle the file differently
        # Create a temporary file object
        temp_file = Tempfile.new(['hrz_lib', File.extname(filename)])
        temp_file.binmode
        temp_file.write(file_content)
        temp_file.rewind

        # Create an ActionDispatch::Http::UploadedFile-like object
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          tempfile: temp_file,
          filename: filename,
          type: content_type
        )

        attachment.file = uploaded_file

        if attachment.save
          temp_file.close
          temp_file.unlink
          HrzLogger.info_msg "HRZ Lib: Successfully attached file '#{filename}' to issue ##{issue_id}"
          return attachment.id
        else
          temp_file.close
          temp_file.unlink
          HrzLogger.error_msg "HRZ Lib: Failed to attach file: #{attachment.errors.full_messages.join(', ')}"
          return nil
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error attaching file: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # attach_file



    # Creates a relation between two issues
    #
    # @param issue_from_id [Integer] The ID of the source issue
    # @param issue_to_id [Integer] The ID of the target issue
    # @param relation_type [String] The type of relation (default: 'relates')
    #   Valid types: 'relates', 'duplicates', 'duplicated', 'blocks', 'blocked',
    #                'precedes', 'follows', 'copied_to', 'copied_from'
    # @param options [Hash] Additional options for the relation
    # @option options [Integer] :delay Delay in days (only for 'precedes'/'follows' relations)
    #
    # @return [Integer, nil] The ID of the created relation, or nil if creation failed
    #
    # @example Basic relation
    #   relation_id = HrzLib::IssueHelper.create_relation(
    #     42,
    #     43,
    #     'relates'
    #   )
    #
    # @example Blocking relation
    #   relation_id = HrzLib::IssueHelper.create_relation(
    #     42,
    #     43,
    #     'blocks'
    #   )
    #
    # @example Precedence with delay
    #   relation_id = HrzLib::IssueHelper.create_relation(
    #     42,
    #     43,
    #     'precedes',
    #     delay: 5
    #   )
    #
    def self.create_relation(issue_from_id, issue_to_id, relation_type = 'relates', options = {})
      begin
        # Valid relation types in Redmine
        valid_types = %w[relates duplicates duplicated blocks blocked precedes follows copied_to copied_from]

        unless valid_types.include?(relation_type)
          HrzLogger.error_msg "HRZ Lib: Invalid relation type '#{relation_type}'. Valid types: #{valid_types.join(', ')}"
          return nil
        end

        # Find both issues to ensure they exist
        issue_from = Issue.find(issue_from_id)
        issue_to = Issue.find(issue_to_id)

        # Check if relation already exists
        existing = IssueRelation.where(
          issue_from_id: issue_from_id,
          issue_to_id: issue_to_id,
          relation_type: relation_type
        ).first

        if existing
          HrzLogger.info_msg "HRZ Lib: Relation already exists between issue ##{issue_from_id} and ##{issue_to_id}"
          return existing.id
        end

        # Create the relation
        relation = IssueRelation.new(
          issue_from_id: issue_from_id,
          issue_to_id: issue_to_id,
          relation_type: relation_type
        )

        # Set delay for precedes/follows relations
        if ['precedes', 'follows'].include?(relation_type) && options[:delay]
          relation.delay = options[:delay]
        end

        if relation.save
          HrzLogger.info_msg "HRZ Lib: Successfully created '#{relation_type}' relation from issue ##{issue_from_id} to ##{issue_to_id}"
          return relation.id
        else
          HrzLogger.error_msg "HRZ Lib: Failed to create relation: #{relation.errors.full_messages.join(', ')}"
          return nil
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error creating relation: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # create_relation



    # Updates an existing issue with new values
    #
    # @param issue_id [Integer] The ID of the issue to update
    # @param attributes [Hash] Hash of attributes to update
    # @option attributes [String] :subject New subject/title
    # @option attributes [String] :description New description
    # @option attributes [Integer] :assigned_to_id New assignee user ID (nil to clear)
    # @option attributes [Integer] :tracker_id New tracker ID
    # @option attributes [Integer] :status_id New status ID
    # @option attributes [Integer] :priority_id New priority ID
    # @option attributes [Integer] :category_id New category ID
    # @option attributes [Integer] :fixed_version_id New target version ID
    # @option attributes [Date, String] :start_date New start date
    # @option attributes [Date, String] :due_date New due date
    # @option attributes [Integer] :estimated_hours New estimated hours
    # @option attributes [Integer] :done_ratio New completion percentage (0-100)
    # @option attributes [Integer] :parent_issue_id New parent issue ID
    # @option attributes [Hash] :custom_fields Custom field values to update
    # @param options [Hash] Additional options
    # @option options [String] :notes Journal notes/comment to add with the update
    # @option options [Boolean] :private_notes Whether the notes should be private (default: false)
    # @option options [Integer] :author_id User ID performing the update (default: User.current)
    #
    # @return [Boolean] true if update was successful, false otherwise
    #
    # @example Update subject and assignee
    #   success = HrzLib::IssueHelper.update_issue(
    #     42,
    #     subject: 'Updated title',
    #     assigned_to_id: 5
    #   )
    #
    # @example Update with journal note
    #   success = HrzLib::IssueHelper.update_issue(
    #     42,
    #     {status_id: 3, done_ratio: 100},
    #     notes: 'Task completed successfully'
    #   )
    #
    # @example Update custom fields
    #   success = HrzLib::IssueHelper.update_issue(
    #     42,
    #     custom_fields: {1 => 'New value', 2 => 'Another value'}
    #   )
    #
    def self.update_issue(issue_id, attributes = {}, options = {})
      begin
        # Find the issue
        issue = Issue.find(issue_id)

        # Set the user context for the update
        author = options[:author_id] ? User.find(options[:author_id]) : User.current
        User.current = author if author

        # Handle custom fields separately
        custom_fields = attributes.delete(:custom_fields)

        # Update standard attributes
        attributes.each do |key, value|
          issue.send("#{key}=", value) if issue.respond_to?("#{key}=")
        end

        # Update custom fields if provided
        if custom_fields && custom_fields.is_a?(Hash)
          custom_fields.each do |field_id, value|
            issue.custom_field_values = {field_id => value}
          end
        end

        # Add journal notes if provided
        if options[:notes]
          issue.notes = options[:notes]
          issue.private_notes = options[:private_notes] || false
        end

        # Save the issue
        if issue.save
          HrzLogger.info_msg "HRZ Lib: Successfully updated issue ##{issue_id}"
          return true
        else
          HrzLogger.error_msg "HRZ Lib: Failed to update issue ##{issue_id}: #{issue.errors.full_messages.join(', ')}"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return false
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error updating issue: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return false
      end
    end  # update_issue



    # Adds a comment (journal entry) to an existing issue
    #
    # @param issue_id [Integer] The ID of the issue to comment on
    # @param comment [String] The comment text
    # @param options [Hash] Additional options for the comment
    # @option options [Boolean] :private Whether the comment should be private (default: false)
    # @option options [Integer] :author_id The author user ID (default: User.current)
    # @option options [Hash] :attribute_changes Hash of attribute changes to log with the comment
    #   Example: {status_id: 3, assigned_to_id: 5}
    #
    # @return [Integer, nil] The ID of the created journal entry, or nil if creation failed
    #
    # @example Simple comment
    #   journal_id = HrzLib::IssueHelper.add_comment(
    #     42,
    #     'This is a progress update'
    #   )
    #
    # @example Private comment
    #   journal_id = HrzLib::IssueHelper.add_comment(
    #     42,
    #     'Internal note: needs review',
    #     private: true
    #   )
    #
    # @example Comment with attribute changes
    #   journal_id = HrzLib::IssueHelper.add_comment(
    #     42,
    #     'Reassigning to John and changing status',
    #     attribute_changes: {status_id: 2, assigned_to_id: 5}
    #   )
    #
    def self.add_comment(issue_id, comment, options = {})
      begin
        # Find the issue
        issue = Issue.find(issue_id)

        # Set the user context
        author = options[:author_id] ? User.find(options[:author_id]) : User.current
        User.current = author if author

        # Initialize journal
        issue.init_journal(author, comment)

        # Set private flag if specified
        if options[:private]
          issue.private_notes = true
        end

        # Apply attribute changes if provided
        if options[:attribute_changes] && options[:attribute_changes].is_a?(Hash)
          options[:attribute_changes].each do |key, value|
            issue.send("#{key}=", value) if issue.respond_to?("#{key}=")
          end
        end

        # Save the issue (this creates the journal entry)
        if issue.save
          journal = issue.journals.last
          if journal
            HrzLogger.info_msg "HRZ Lib: Successfully added comment to issue ##{issue_id}"
            return journal.id
          else
            HrzLogger.error_msg "HRZ Lib: Comment was saved but journal entry not found"
            return nil
          end
        else
          HrzLogger.error_msg "HRZ Lib: Failed to add comment to issue ##{issue_id}: #{issue.errors.full_messages.join(', ')}"
          return nil
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error adding comment: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # add_comment



    # Reads an existing Redmine issue and returns it as a hash compatible with mk_issue
    # @param issue_id      [Integer]           The ID of the issue to read
    # @param q_resolve_hrz [Boolean, optional] Resolve <HRZ> tags in strings? true=yes, false=no, return strings verbatim.
    # @return [Hash, nil] Hash containing issue data compatible with mk_issue parameters, or nil on error
    #   The returned hash contains:
    #   - :project_id      [String]         - Project identifier
    #   - :b_subject       [String]         - Issue subject (processed through TagStringHelper.str_hrz)
    #   - :b_desc          [String]         - Issue description (processed through TagStringHelper.str_hrz)
    #   - :j_assignee      [Integer, nil]   - Assigned user ID
    #   - :arr_watcher_ids [Array<Integer>] - Array of watcher user IDs
    #   - :options         [Hash]           - Hash with additional options:
    #     - :tracker_id        [Integer]
    #     - :status_id         [Integer]
    #     - :priority_id       [Integer]
    #     - :category_id       [Integer, nil]
    #     - :target_version_id [Integer, nil]
    #     - :start_date        [String, nil]
    #     - :due_date          [String, nil]
    #     - :estimated_hours   [Float, nil]
    #     - :done_ratio        [Integer]
    #     - :parent_issue_id   [Integer, nil]
    #     - :custom_fields     [Hash] - Custom field values (all processed through TagStringHelper.str_hrz)
    #     - :author_id         [Integer]
    #
    # @example Read an issue and create a copy
    #   issue_data = HrzLib::IssueHelper.get_issue(42)
    #   if issue_data
    #     new_issue_id = HrzLib::IssueHelper.mk_issue(
    #       issue_data[:project_id],
    #       issue_data[:b_subject],
    #       issue_data[:b_desc],
    #       issue_data[:j_assignee],
    #       issue_data[:arr_watcher_ids],
    #       issue_data[:options]
    #     )
    #   end
    #
    # @example Read and modify before creating
    #   issue_data = HrzLib::IssueHelper.get_issue(42)
    #   if issue_data
    #     issue_data[:b_subject] = "Copy: #{issue_data[:b_subject]}"
    #     issue_data[:options][:status_id] = 1  # Reset to new status
    #     new_issue_id = HrzLib::IssueHelper.mk_issue(
    #       issue_data[:project_id],
    #       issue_data[:b_subject],
    #       issue_data[:b_desc],
    #       issue_data[:j_assignee],
    #       [],  # No watchers for copy
    #       issue_data[:options]
    #     )
    #   end
    #
    def self.get_issue(issue_id, q_resolve_hrz=true)
      return nil  if issue_id.nil?
      begin
        # Find the issue
        issue = Issue.find(issue_id)

        # Process subject and description through TagStringHelper
        if q_resolve_hrz
           subject     = TagStringHelper.str_hrz(issue.subject     || '')
           description = TagStringHelper.str_hrz(issue.description || '')
        else
           subject     = issue.subject     || ''
           description = issue.description || ''
        end

        # Get watcher user IDs
        watcher_ids = issue.watcher_users.pluck(:id)

        # Build custom fields hash with processed values
        custom_fields = {}
        issue.custom_field_values.each do |custom_value|
          field_id = custom_value.custom_field.id
          value = custom_value.value

          # Process text values through TagStringHelper
          if q_resolve_hrz && value.is_a?(String)
            custom_fields[field_id] = TagStringHelper.str_hrz(value)
          else
            custom_fields[field_id] = value
          end
        end

        # Build options hash
        options = {
          tracker_id: issue.tracker_id,
          status_id: issue.status_id,
          priority_id: issue.priority_id,
          category_id: issue.category_id,
          target_version_id: issue.fixed_version_id,
          start_date: issue.start_date&.to_s,
          due_date: issue.due_date&.to_s,
          estimated_hours: issue.estimated_hours,
          done_ratio: issue.done_ratio,
          parent_issue_id: issue.parent_issue_id,
          author_id: issue.author_id
        }

        # Add custom fields to options if any exist
        options[:custom_fields] = custom_fields unless custom_fields.empty?

        # Build result hash compatible with mk_issue
        result = {
          project_id: issue.project.identifier,
          b_subject: subject,
          b_desc: description,
          j_assignee: issue.assigned_to_id,
          arr_watcher_ids: watcher_ids,
          options: options
        }

        #HrzLogger.info_msg "HRZ Lib get_issue: Successfully read issue ##{issue_id}"
        return result

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib get_issue: Issue ##{issue_id} not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib get_issue: Error reading issue ##{issue_id}: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # get_issue



    # ------------------------------------------------------------------------------------------------------------------------------
    # Watchers
    # ------------------------------------------------------------------------------------------------------------------------------

    # Adds a watcher to an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param user_id [Integer] The ID of the user to add as watcher
    #
    # @return [Boolean] true if watcher was added successfully, false otherwise
    #
    # @example Add single watcher
    #   success = HrzLib::IssueHelper.add_watcher(42, 5)
    #
    def self.add_watcher(issue_id, user_id)
      begin
        issue = Issue.find(issue_id)
        user = User.find(user_id)

        # Check if user is already watching
        if Watcher.where(watchable: issue, user: user).exists?
          HrzLogger.info_msg "HRZ Lib: User ##{user_id} is already watching issue ##{issue_id}"
          return true
        end

        # Create watcher
        watcher = Watcher.new(watchable: issue, user: user)

        if watcher.save
          HrzLogger.info_msg "HRZ Lib: Successfully added user ##{user_id} as watcher to issue ##{issue_id}"
          return true
        else
          HrzLogger.error_msg "HRZ Lib: Failed to add watcher: #{watcher.errors.full_messages.join(', ')}"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue or user not found: #{e.message}"
        return false
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error adding watcher: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return false
      end
    end  # add_watcher



    # Adds multiple watchers to an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param user_ids [Array<Integer>] Array of user IDs to add as watchers
    #
    # @return [Hash] Hash with :success (count) and :failed (array of user_ids) keys
    #
    # @example Add multiple watchers
    #   result = HrzLib::IssueHelper.add_watchers(42, [3, 5, 7, 9])
    #   # => {success: 3, failed: [9]}
    #
    def self.add_watchers(issue_id, user_ids)
      return {success: 0, failed: []} if user_ids.nil? || user_ids.empty?

      success_count = 0
      failed_ids = []

      user_ids.each do |user_id|
        if add_watcher(issue_id, user_id)
          success_count += 1
        else
          failed_ids << user_id
        end
      end

      HrzLogger.info_msg "HRZ Lib: Added #{success_count} watchers to issue ##{issue_id}, #{failed_ids.length} failed"

      {success: success_count, failed: failed_ids}
    end  # add_watchers



    # Removes a watcher from an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param user_id [Integer] The ID of the user to remove as watcher
    #
    # @return [Boolean] true if watcher was removed successfully, false otherwise
    #
    # @example Remove watcher
    #   success = HrzLib::IssueHelper.remove_watcher(42, 5)
    #
    def self.remove_watcher(issue_id, user_id)
      begin
        issue = Issue.find(issue_id)
        user = User.find(user_id)

        # Find the watcher
        watcher = Watcher.where(watchable: issue, user: user).first

        if watcher.nil?
          HrzLogger.info_msg "HRZ Lib: User ##{user_id} is not watching issue ##{issue_id}"
          return true
        end

        if watcher.destroy
          HrzLogger.info_msg "HRZ Lib: Successfully removed user ##{user_id} as watcher from issue ##{issue_id}"
          return true
        else
          HrzLogger.error_msg "HRZ Lib: Failed to remove watcher"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue or user not found: #{e.message}"
        return false
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error removing watcher: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return false
      end
    end  # remove_watcher



    # Removes multiple watchers from an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param user_ids [Array<Integer>] Array of user IDs to remove as watchers
    #
    # @return [Hash] Hash with :success (count) and :failed (array of user_ids) keys
    #
    # @example Remove multiple watchers
    #   result = HrzLib::IssueHelper.remove_watchers(42, [3, 5, 7])
    #   # => {success: 3, failed: []}
    #
    def self.remove_watchers(issue_id, user_ids)
      return {success: 0, failed: []} if user_ids.nil? || user_ids.empty?

      success_count = 0
      failed_ids = []

      user_ids.each do |user_id|
        if remove_watcher(issue_id, user_id)
          success_count += 1
        else
          failed_ids << user_id
        end
      end

      HrzLogger.info_msg "HRZ Lib: Removed #{success_count} watchers from issue ##{issue_id}, #{failed_ids.length} failed"

      {success: success_count, failed: failed_ids}
    end  # remove_watchers



    # Gets all watchers of an issue
    #
    # @param issue_id [Integer] The ID of the issue
    #
    # @return [Array<Hash>, nil] Array of hashes with watcher info, or nil on error
    #   Each hash contains: {id: user_id, login: username, name: full_name}
    #
    # @example Get all watchers
    #   watchers = HrzLib::IssueHelper.get_watchers(42)
    #   # => [{id: 3, login: 'jdoe', name: 'John Doe'}, ...]
    #
    def self.get_watchers(issue_id)
      begin
        issue = Issue.find(issue_id)

        watchers = issue.watcher_users.map do |user|
          {
            id: user.id,
            login: user.login,
            name: "#{user.firstname} #{user.lastname}".strip
          }
        end

        HrzLogger.info_msg "HRZ Lib: Retrieved #{watchers.length} watchers for issue ##{issue_id}"
        return watchers

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error getting watchers: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # get_watchers



    # Checks if a user is watching an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param user_id [Integer] The ID of the user to check
    #
    # @return [Boolean, nil] true if user is watching, false if not, nil on error
    #
    # @example Check if user is watching
    #   is_watching = HrzLib::IssueHelper.is_watching?(42, 5)
    #
    def self.is_watching?(issue_id, user_id)
      begin
        issue = Issue.find(issue_id)
        user = User.find(user_id)

        watching = Watcher.where(watchable: issue, user: user).exists?

        HrzLogger.info_msg "HRZ Lib: User ##{user_id} is #{watching ? '' : 'not '}watching issue ##{issue_id}"
        return watching

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue or user not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error checking watcher status: #{e.message}"
        return nil
      end
    end  # is_watching?



    # Replaces all watchers of an issue with a new set of watchers
    #
    # @param issue_id [Integer] The ID of the issue
    # @param user_ids [Array<Integer>] Array of user IDs to set as watchers
    #
    # @return [Boolean] true if operation was successful, false otherwise
    #
    # @example Set watchers (replaces existing)
    #   success = HrzLib::IssueHelper.set_watchers(42, [3, 5, 7])
    #
    def self.set_watchers(issue_id, user_ids)
      begin
        issue = Issue.find(issue_id)

        # Remove all existing watchers
        issue.watcher_users.clear

        # Add new watchers
        if user_ids && !user_ids.empty?
          result = add_watchers(issue_id, user_ids)
          success = result[:failed].empty?
        else
          success = true
        end

        if success
          HrzLogger.info_msg "HRZ Lib: Successfully set watchers for issue ##{issue_id}"
        else
          HrzLogger.warning_msg "HRZ Lib: Set watchers partially successful for issue ##{issue_id}"
        end

        return success

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return false
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error setting watchers: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return false
      end
    end  # set_watchers



    # ------------------------------------------------------------------------------------------------------------------------------
    # Related Issue and Sub-Task Search
    # ------------------------------------------------------------------------------------------------------------------------------

    # The methods below have the following things in common:
    # * find_* ............... returns an issue ID, if one was found or nil, if no such issue was found.
    # * has_*with_subject? ... returns true = found, false = not found.
    # * All of them .......... return nil, if the main_issue was not found.


    # Finds the ID of a related issue that has the search text in its subject
    # This is the inner method that returns the actual issue ID found
    #
    # @param j_issue_main_id [Integer] The ID of the main issue whose related issues should be searched
    # @param b_txt_find [String] The text to search for in related issue subjects (case-insensitive)
    #
    # @return [Integer, nil] The ID of the first related issue found with the search text in its subject,
    #   or nil if no match found, no related issues exist, or an error occurred
    #
    # @example Find related issue with keyword
    #   found_id = HrzLib::IssueHelper.find_related_with_subject(42, 'deployment')
    #   if found_id
    #     puts "Found issue ##{found_id}"
    #     issue = Issue.find(found_id)
    #   end
    #
    def self.find_related_with_subject(j_issue_main_id, b_txt_find)
      begin
        # Find the main issue
        issue = Issue.find(j_issue_main_id)

        # Normalize search text for case-insensitive search
        search_text = b_txt_find.to_s.downcase

        # Return nil if search text is empty
        return nil if search_text.empty?

        # Get all relations where this issue is the source
        relations_from = IssueRelation.where(issue_from_id: issue.id)

        # Get all relations where this issue is the target (need to check both directions)
        relations_to = IssueRelation.where(issue_to_id: issue.id)

        # Check relations where this issue is the source
        relations_from.each do |relation|
          begin
            related_issue = Issue.find(relation.issue_to_id)
            if related_issue.subject.downcase.include?(search_text)
              #HrzLogger.info_msg "HRZ Lib: Found text '#{b_txt_find}' in related issue ##{related_issue.id} (relation from ##{issue.id})"
              return related_issue.id
            end
          rescue ActiveRecord::RecordNotFound
            #HrzLogger.warning_msg "HRZ Lib: Related issue ##{relation.issue_to_id} not found"
            next
          end
        end

        # Check relations where this issue is the target
        relations_to.each do |relation|
          begin
            related_issue = Issue.find(relation.issue_from_id)
            if related_issue.subject.downcase.include?(search_text)
              #HrzLogger.info_msg "HRZ Lib: Found text '#{b_txt_find}' in related issue ##{related_issue.id} (relation to ##{issue.id})"
              return related_issue.id
            end
          rescue ActiveRecord::RecordNotFound
            #HrzLogger.warning_msg "HRZ Lib: Related issue ##{relation.issue_from_id} not found"
            next
          end
        end

        # No match found
        #HrzLogger.info_msg "HRZ Lib: No related issues with text '#{b_txt_find}' found for issue ##{issue.id}"
        return nil

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib find_related_with_subject: Issue ##{j_issue_main_id} not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib find_related_with_subject: Error searching related issues: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # find_related_with_subject



    # Checks if any related issue has the search text in its subject
    # This is the outer method that returns a boolean result
    #
    # @param j_issue_main_id [Integer] The ID of the main issue whose related issues should be searched
    # @param b_txt_find [String] The text to search for in related issue subjects (case-insensitive)
    #
    # @return [Boolean, nil] true if at least one related issue contains the search text in its subject,
    #   false if no related issues contain the text or no related issues exist,
    #   nil if the main issue was not found or an error occurred
    #
    # @example Check for keyword in related issues
    #   has_match = HrzLib::IssueHelper.has_related_with_subject?(42, 'deployment')
    #   if has_match
    #     puts "Found related issue with 'deployment' in subject"
    #   end
    #
    # @example Check across all relation types
    #   # Searches in all related issues regardless of relation type (relates, blocks, precedes, etc.)
    #   has_match = HrzLib::IssueHelper.has_related_with_subject?(42, 'critical bug')
    #
    def self.has_related_with_subject?(j_issue_main_id, b_txt_find)
      begin
        # Find the main issue first to distinguish between "not found" and "no matches"
        Issue.find(j_issue_main_id)

        # Use the inner method to find a matching issue
        found_id = find_related_with_subject(j_issue_main_id, b_txt_find)

        # Return true if found, false if not found (but issue exists)
        return found_id.present?

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib has_related_with_subject?: Issue ##{j_issue_main_id} not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib has_related_with_subject?: Error in has_related_with_subject?: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # has_related_with_subject?



    # Finds the ID of a sub-task that has the search text in its subject
    # This is the inner method that returns the actual issue ID found
    #
    # @param j_issue_main_id [Integer] The ID of the parent issue whose sub-tasks should be searched
    # @param b_txt_find [String] The text to search for in sub-task subjects (case-insensitive)
    #
    # @return [Integer, nil] The ID of the first sub-task found with the search text in its subject,
    #   or nil if no match found, no sub-tasks exist, or an error occurred
    #
    # @example Find sub-task with keyword
    #   found_id = HrzLib::IssueHelper.find_subtask_with_subject(42, 'testing')
    #   if found_id
    #     puts "Found subtask ##{found_id}"
    #     subtask = Issue.find(found_id)
    #   end
    #
    def self.find_subtask_with_subject(j_issue_main_id, b_txt_find)
      begin
        # Find the parent issue
        issue = Issue.find(j_issue_main_id)

        # Normalize search text for case-insensitive search
        search_text = b_txt_find.to_s.downcase

        # Return nil if search text is empty
        return nil if search_text.empty?

        # Get all sub-tasks (children) of this issue
        subtasks = issue.children

        # Return nil if no sub-tasks exist
        if subtasks.empty?
          #HrzLogger.info_msg "HRZ Lib: No sub-tasks found for issue ##{issue.id}"
          return nil
        end

        # Search through all sub-tasks
        subtasks.each do |subtask|
          if subtask.subject.downcase.include?(search_text)
            #HrzLogger.info_msg "HRZ Lib: Found text '#{b_txt_find}' in sub-task ##{subtask.id} of issue ##{issue.id}"
            return subtask.id
          end
        end

        # No match found
        #HrzLogger.info_msg "HRZ Lib: No sub-tasks with text '#{b_txt_find}' found for issue ##{issue.id} (checked #{subtasks.count} sub-tasks)"
        return nil

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib find_subtask_with_subject: Issue ##{j_issue_main_id} not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib find_subtask_with_subject: Error searching sub-tasks: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # find_subtask_with_subject



    # Checks if any sub-task has the search text in its subject
    # This is the outer method that returns a boolean result
    #
    # @param j_issue_main_id [Integer] The ID of the parent issue whose sub-tasks should be searched
    # @param b_txt_find [String] The text to search for in sub-task subjects (case-insensitive)
    #
    # @return [Boolean, nil] true if at least one sub-task contains the search text in its subject,
    #   false if no sub-tasks contain the text or no sub-tasks exist,
    #   nil if the parent issue was not found or an error occurred
    #
    # @example Check for keyword in sub-tasks
    #   has_match = HrzLib::IssueHelper.has_subtask_with_subject?(42, 'testing')
    #   if has_match
    #     puts "Found sub-task with 'testing' in subject"
    #   end
    #
    # @example Search for multiple words
    #   has_match = HrzLib::IssueHelper.has_subtask_with_subject?(42, 'code review completed')
    #
    def self.has_subtask_with_subject?(j_issue_main_id, b_txt_find)
      begin
        # Find the parent issue first to distinguish between "not found" and "no matches"
        Issue.find(j_issue_main_id)

        # Use the inner method to find a matching subtask
        found_id = find_subtask_with_subject(j_issue_main_id, b_txt_find)

        # Return true if found, false if not found (but parent issue exists)
        return found_id.present?

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib has_subtask_with_subject?: Issue ##{j_issue_main_id} not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib has_subtask_with_subject?: Error in has_subtask_with_subject?: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # has_subtask_with_subject?



    # ------------------------------------------------------------------------------------------------------------------------------
    # Time entries
    # ------------------------------------------------------------------------------------------------------------------------------

    # Creates a time entry for an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param hours [Float] The number of hours to log
    # @param options [Hash] Additional options for the time entry
    # @option options [Integer] :activity_id The activity ID (required if project has multiple activities)
    # @option options [String] :comments Comments/description for the time entry
    # @option options [Date, String] :spent_on The date when time was spent (default: today)
    # @option options [Integer] :user_id The user who spent the time (default: User.current)
    # @option options [Hash] :custom_fields Custom field values for the time entry
    #
    # @return [Integer, nil] The ID of the created time entry, or nil if creation failed
    #
    # @example Basic time entry
    #   time_entry_id = HrzLib::IssueHelper.create_time_entry(
    #     42,
    #     2.5,
    #     activity_id: 9,
    #     comments: 'Development work'
    #   )
    #
    # @example With specific date and user
    #   time_entry_id = HrzLib::IssueHelper.create_time_entry(
    #     42,
    #     4.0,
    #     activity_id: 9,
    #     spent_on: '2025-12-10',
    #     user_id: 5,
    #     comments: 'Bug fixing'
    #   )
    #
    def self.create_time_entry(issue_id, hours, options = {})
      begin
        issue = Issue.find(issue_id)

        # Get user
        user = options[:user_id] ? User.find(options[:user_id]) : User.current

        # Create time entry
        time_entry = TimeEntry.new
        time_entry.project = issue.project
        time_entry.issue = issue
        time_entry.user = user
        time_entry.hours = hours
        time_entry.spent_on = options[:spent_on] || Date.today
        time_entry.comments = options[:comments] if options[:comments]

        # Set activity
        if options[:activity_id]
          time_entry.activity_id = options[:activity_id]
        else
          # Use first available activity if not specified
          default_activity = TimeEntryActivity.active.first
          if default_activity
            time_entry.activity_id = default_activity.id
          else
            HrzLogger.error_msg "HRZ Lib: No active time entry activity found"
            return nil
          end
        end

        # Set custom fields if provided
        if options[:custom_fields] && options[:custom_fields].is_a?(Hash)
          options[:custom_fields].each do |field_id, value|
            time_entry.custom_field_values = {field_id => value}
          end
        end

        if time_entry.save
          HrzLogger.info_msg "HRZ Lib: Successfully created time entry for issue ##{issue_id}: #{hours}h"
          return time_entry.id
        else
          HrzLogger.error_msg "HRZ Lib: Failed to create time entry: #{time_entry.errors.full_messages.join(', ')}"
          return nil
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue or user not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error creating time entry: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # create_time_entry



    # Updates an existing time entry
    #
    # @param time_entry_id [Integer] The ID of the time entry to update
    # @param attributes [Hash] Hash of attributes to update
    # @option attributes [Float] :hours New hours value
    # @option attributes [String] :comments New comments
    # @option attributes [Date, String] :spent_on New date
    # @option attributes [Integer] :activity_id New activity ID
    # @option attributes [Hash] :custom_fields Custom field values to update
    #
    # @return [Boolean] true if update was successful, false otherwise
    #
    # @example Update hours and comments
    #   success = HrzLib::IssueHelper.update_time_entry(
    #     123,
    #     hours: 3.5,
    #     comments: 'Updated time spent'
    #   )
    #
    def self.update_time_entry(time_entry_id, attributes = {})
      begin
        time_entry = TimeEntry.find(time_entry_id)

        # Handle custom fields separately
        custom_fields = attributes.delete(:custom_fields)

        # Update standard attributes
        attributes.each do |key, value|
          time_entry.send("#{key}=", value) if time_entry.respond_to?("#{key}=")
        end

        # Update custom fields if provided
        if custom_fields && custom_fields.is_a?(Hash)
          custom_fields.each do |field_id, value|
            time_entry.custom_field_values = {field_id => value}
          end
        end

        if time_entry.save
          HrzLogger.info_msg "HRZ Lib: Successfully updated time entry ##{time_entry_id}"
          return true
        else
          HrzLogger.error_msg "HRZ Lib: Failed to update time entry: #{time_entry.errors.full_messages.join(', ')}"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Time entry not found: #{e.message}"
        return false
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error updating time entry: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return false
      end
    end  # update_time_entry



    # Deletes a time entry
    #
    # @param time_entry_id [Integer] The ID of the time entry to delete
    #
    # @return [Boolean] true if deletion was successful, false otherwise
    #
    # @example Delete time entry
    #   success = HrzLib::IssueHelper.delete_time_entry(123)
    #
    def self.delete_time_entry(time_entry_id)
      begin
        time_entry = TimeEntry.find(time_entry_id)

        if time_entry.destroy
          HrzLogger.info_msg "HRZ Lib: Successfully deleted time entry ##{time_entry_id}"
          return true
        else
          HrzLogger.error_msg "HRZ Lib: Failed to delete time entry"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Time entry not found: #{e.message}"
        return false
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error deleting time entry: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return false
      end
    end  # delete_time_entry



    # Gets all time entries for an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param options [Hash] Additional filtering options
    # @option options [Integer] :user_id Filter by specific user
    # @option options [Date, String] :from_date Filter entries from this date onwards
    # @option options [Date, String] :to_date Filter entries up to this date
    #
    # @return [Array<Hash>, nil] Array of hashes with time entry info, or nil on error
    #   Each hash contains: {id, hours, comments, spent_on, activity_name, user_name}
    #
    # @example Get all time entries for an issue
    #   entries = HrzLib::IssueHelper.get_time_entries(42)
    #
    # @example Get time entries for specific user in date range
    #   entries = HrzLib::IssueHelper.get_time_entries(
    #     42,
    #     user_id: 5,
    #     from_date: '2025-12-01',
    #     to_date: '2025-12-31'
    #   )
    #
    def self.get_time_entries(issue_id, options = {})
      begin
        issue = Issue.find(issue_id)

        # Start with all time entries for the issue
        entries = issue.time_entries

        # Apply filters
        entries = entries.where(user_id: options[:user_id]) if options[:user_id]
        entries = entries.where('spent_on >= ?', options[:from_date]) if options[:from_date]
        entries = entries.where('spent_on <= ?', options[:to_date]) if options[:to_date]

        # Map to hash array
        result = entries.map do |entry|
          {
            id: entry.id,
            hours: entry.hours,
            comments: entry.comments,
            spent_on: entry.spent_on.to_s,
            activity_id: entry.activity_id,
            activity_name: entry.activity.name,
            user_id: entry.user_id,
            user_name: "#{entry.user.firstname} #{entry.user.lastname}".strip
          }
        end

        HrzLogger.info_msg "HRZ Lib: Retrieved #{result.length} time entries for issue ##{issue_id}"
        return result

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error getting time entries: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # get_time_entries



    # Gets the total hours logged for an issue
    #
    # @param issue_id [Integer] The ID of the issue
    # @param options [Hash] Additional filtering options
    # @option options [Integer] :user_id Filter by specific user
    # @option options [Date, String] :from_date Filter entries from this date onwards
    # @option options [Date, String] :to_date Filter entries up to this date
    #
    # @return [Float, nil] Total hours, or nil on error
    #
    # @example Get total hours for an issue
    #   total = HrzLib::IssueHelper.get_total_hours(42)
    #   # => 12.5
    #
    # @example Get total hours for specific user
    #   total = HrzLib::IssueHelper.get_total_hours(42, user_id: 5)
    #
    def self.get_total_hours(issue_id, options = {})
      begin
        issue = Issue.find(issue_id)

        # Start with all time entries for the issue
        entries = issue.time_entries

        # Apply filters
        entries = entries.where(user_id: options[:user_id]) if options[:user_id]
        entries = entries.where('spent_on >= ?', options[:from_date]) if options[:from_date]
        entries = entries.where('spent_on <= ?', options[:to_date]) if options[:to_date]

        total = entries.sum(:hours)

        HrzLogger.info_msg "HRZ Lib: Total hours for issue ##{issue_id}: #{total}"
        return total

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Issue not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error calculating total hours: #{e.message}"
        return nil
      end
    end  # get_total_hours



    # Gets available time entry activities
    #
    # @return [Array<Hash>, nil] Array of hashes with activity info, or nil on error
    #   Each hash contains: {id, name, is_default, active}
    #
    # @example Get all activities
    #   activities = HrzLib::IssueHelper.get_time_entry_activities
    #   # => [{id: 9, name: 'Development', is_default: true, active: true}, ...]
    #
    def self.get_time_entry_activities
      begin
        activities = TimeEntryActivity.all.map do |activity|
          {
            id: activity.id,
            name: activity.name,
            is_default: activity.is_default,
            active: activity.active
          }
        end

        HrzLogger.info_msg "HRZ Lib: Retrieved #{activities.length} time entry activities"
        return activities

      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error getting time entry activities: #{e.message}"
        return nil
      end
    end  # get_time_entry_activities


    # Gets the total hours logged by a user on a specific date (across all issues)
    #
    # @param user_id [Integer] The ID of the user
    # @param date [Date, String] The date to check (default: today)
    # @param options [Hash] Additional filtering options
    # @option options [Integer, String] :project_id Filter by specific project
    # @option options [Integer] :activity_id Filter by specific activity
    #
    # @return [Hash, nil] Hash with total hours and details, or nil on error
    #   Returns: {total_hours, entries_count, date, entries: [{issue_id, issue_subject, hours, comments, activity_name}]}
    #
    # @example Get total hours for user today
    #   result = HrzLib::IssueHelper.get_user_daily_hours(5)
    #   puts "Total today: #{result[:total_hours]}h in #{result[:entries_count]} entries"
    #
    # @example Get total hours for specific date
    #   result = HrzLib::IssueHelper.get_user_daily_hours(5, '2025-12-10')
    #
    # @example Get total hours for user in specific project
    #   result = HrzLib::IssueHelper.get_user_daily_hours(5, Date.today, project_id: 'myproject')
    #
    # @example Detailed breakdown
    #   result = HrzLib::IssueHelper.get_user_daily_hours(5)
    #   result[:entries].each do |entry|
    #     puts "##{entry[:issue_id]} - #{entry[:issue_subject]}: #{entry[:hours]}h"
    #   end
    #
    def self.get_user_daily_hours(user_id, date = Date.today, options = {})
      begin
        user = User.find(user_id)
        date = Date.parse(date.to_s) unless date.is_a?(Date)

        # Get all time entries for the user on the specified date
        entries = TimeEntry.where(user_id: user_id, spent_on: date)

        # Apply project filter if specified
        if options[:project_id]
          project = Project.find(options[:project_id])
          entries = entries.where(project_id: project.id)
        end

        # Apply activity filter if specified
        entries = entries.where(activity_id: options[:activity_id]) if options[:activity_id]

        # Calculate total hours
        total_hours = entries.sum(:hours)

        # Map entries to detailed array
        detailed_entries = entries.includes(:issue, :activity).map do |entry|
          {
            id: entry.id,
            issue_id: entry.issue_id,
            issue_subject: entry.issue ? entry.issue.subject : 'N/A',
            project_id: entry.project_id,
            project_name: entry.project.name,
            hours: entry.hours,
            comments: entry.comments,
            activity_id: entry.activity_id,
            activity_name: entry.activity.name
          }
        end

        result = {
          total_hours: total_hours,
          entries_count: entries.count,
          date: date.to_s,
          user_id: user_id,
          user_name: "#{user.firstname} #{user.lastname}".strip,
          entries: detailed_entries
        }

        HrzLogger.info_msg "HRZ Lib: User ##{user_id} logged #{total_hours}h on #{date} (#{entries.count} entries)"
        return result

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: User or project not found: #{e.message}"
        return nil
      rescue ArgumentError => e
        HrzLogger.error_msg "HRZ Lib: Invalid date format: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error calculating user daily hours: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # get_user_daily_hours



    # Gets the total hours logged by a user in a date range (across all issues)
    #
    # @param user_id [Integer] The ID of the user
    # @param from_date [Date, String] Start date of the range
    # @param to_date [Date, String] End date of the range (default: from_date)
    # @param options [Hash] Additional filtering options
    # @option options [Integer, String] :project_id Filter by specific project
    # @option options [Integer] :activity_id Filter by specific activity
    # @option options [Boolean] :group_by_date Return results grouped by date (default: false)
    #
    # @return [Hash, nil] Hash with total hours and details, or nil on error
    #
    # @example Get total hours for current week
    #   result = HrzLib::IssueHelper.get_user_hours_range(
    #     5,
    #     Date.today.beginning_of_week,
    #     Date.today.end_of_week
    #   )
    #   puts "This week: #{result[:total_hours]}h"
    #
    # @example Get hours grouped by day
    #   result = HrzLib::IssueHelper.get_user_hours_range(
    #     5,
    #     '2025-12-01',
    #     '2025-12-31',
    #     group_by_date: true
    #   )
    #   result[:by_date].each do |date, data|
    #     puts "#{date}: #{data[:hours]}h"
    #   end
    #
    def self.get_user_hours_range(user_id, from_date, to_date = nil, options = {})
      begin
        user = User.find(user_id)
        from_date = Date.parse(from_date.to_s) unless from_date.is_a?(Date)
        to_date = to_date ? (Date.parse(to_date.to_s) unless to_date.is_a?(Date)) : from_date

        # Get all time entries for the user in the date range
        entries = TimeEntry.where(user_id: user_id, spent_on: from_date..to_date)

        # Apply filters
        if options[:project_id]
          project = Project.find(options[:project_id])
          entries = entries.where(project_id: project.id)
        end
        entries = entries.where(activity_id: options[:activity_id]) if options[:activity_id]

        # Calculate total hours
        total_hours = entries.sum(:hours)

        result = {
          total_hours: total_hours,
          entries_count: entries.count,
          from_date: from_date.to_s,
          to_date: to_date.to_s,
          user_id: user_id,
          user_name: "#{user.firstname} #{user.lastname}".strip
        }

        # Group by date if requested
        if options[:group_by_date]
          by_date = entries.group_by { |e| e.spent_on.to_s }.transform_values do |day_entries|
            {
              hours: day_entries.sum(&:hours),
              entries_count: day_entries.count,
              entries: day_entries.map do |e|
                {
                  id: e.id,
                  issue_id: e.issue_id,
                  issue_subject: e.issue ? e.issue.subject : 'N/A',
                  hours: e.hours,
                  comments: e.comments,
                  activity_name: e.activity.name
                }
              end
            }
          end
          result[:by_date] = by_date
        end

        HrzLogger.info_msg "HRZ Lib: User ##{user_id} logged #{total_hours}h from #{from_date} to #{to_date}"
        return result

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: User or project not found: #{e.message}"
        return nil
      rescue ArgumentError => e
        HrzLogger.error_msg "HRZ Lib: Invalid date format: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error calculating user hours range: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # get_user_hours_range



    # ------------------------------------------------------------------------------------------------------------------------------
    # Redmine group information
    # ------------------------------------------------------------------------------------------------------------------------------

    # Gets members of a Redmine group or information about a user
    #
    # @param principal_id [Integer] The ID of a group or user
    # @return [Hash, nil] Hash containing member information, or nil on error
    #   For groups:
    #   - :arr_member_ids [Array<Integer>] - Array of user IDs who are members of the group.
    #   - :leader_id      [Integer, nil]   - Value from custom field "Leader ID", if it exists.
    #   - :leader_name    [String, nil]    - Value from custom field "Leader Name", if it exists.
    #   For users:
    #   - :arr_member_ids [Array]   - Empty array
    #   - :leader_id      [Integer] - The user's ID
    #   - :leader_name    [String]  - The user's display name (firstname lastname)
    #
    # @example Get group members
    #   result = HrzLib::IssueHelper.get_group_members(15)
    #   # => {members: [3, 5, 7, 12], leader_id: 5, leader_name: "John Doe"}
    #
    # @example Get user info
    #   result = HrzLib::IssueHelper.get_group_members(42)
    #   # => {members: [], leader_id: 42, leader_name: "Jane Smith"}
    #
    # @example Check if it's a group with members
    #   result = HrzLib::IssueHelper.get_group_members(15)
    #   if result && result[:members].any?
    #     puts "Group has #{result[:members].count} members"
    #     puts "Leader: #{result[:leader_name]}" if result[:leader_name]
    #   end
    #
    def self.get_group_members(principal_id)
      begin
        # Try to find as Principal first (can be User or Group)
        principal = Principal.find(principal_id)

        result = {
          arr_member_ids: [],
          leader_id: nil,
          leader_name: nil
        }

        if principal.is_a?(Group)
          # It's a group - get all user members
          result[:arr_member_ids] = principal.users.pluck(:id)

          # Try to find custom fields "Leader ID" and "Leader Name"
          principal.custom_field_values.each do |custom_value|
            field_name = custom_value.custom_field.name
            value = custom_value.value

            case field_name
              when "Leader ID", "Leader"
                # Try to convert to integer if it's a string
                result[:leader_id] = value.to_i if value.present?
              when "Leader Name"
                result[:leader_name] = value if value.present?
            end
          end

          #HrzLogger.debug_msg "HRZ Lib: Group ##{principal_id} has #{result[:arr_member_ids].count} members."

        elsif principal.is_a?(User)
          # It's a user - return empty members array and user info as leader
          result[:arr_member_ids] = []
          result[:leader_id] = principal.id
          result[:leader_name] = "#{principal.firstname} #{principal.lastname}".strip

          #HrzLogger.debug_msg "HRZ Lib: Principal ##{principal_id} is a user: #{result[:leader_name]}"

        else
          # Unknown principal type
          HrzLogger.debug_msg "HRZ Lib: Principal ##{principal_id} is neither Group nor User"
          return nil
        end

        return result

      rescue ActiveRecord::RecordNotFound => e
        HrzLogger.error_msg "HRZ Lib: Principal ##{principal_id} not found: #{e.message}"
        return nil
      rescue => e
        HrzLogger.error_msg "HRZ Lib: Error getting group members for ##{principal_id}: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # get_group_members

  end  # module IssueHelper
end  # module HrzLib
