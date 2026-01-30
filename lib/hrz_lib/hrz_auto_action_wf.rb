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
# Purpose: Collect data for automatic actions from Redmine Custom Workflow plugin.


module HrzLib
  module HrzAutoActionWf

    # Collect data for automatic actions from Redmine Custom Workflow plugin.
    # @param issue_wf     Issue object from Redmine Custom Workflow plugin: "self"
    # Usage: HrzLib::HrzAutoActionWf.collect_issue_data_wf(self)
    def self.collect_issue_data_wf(issue_wf)
      # Collect the current ticket's data:
      # a) new status, not stored yet.

      # Project name / numeric ID / text ID ("my-project"):
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'project_name',        issue_wf.project.try(:name))
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'project_id',          issue_wf.project_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'project_identifier',  issue_wf.project.try(:identifier))
      #HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'project_ai_model_id', get_ai_model_appl_id(issue_wf.project))

      # Ticket ID, Subject:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'issue_id',           issue_wf.id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'subject',            issue_wf.subject)
      # Description:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'description',        issue_wf.description)
      # Notes, except the latest:
      b_txt_note_new  = ''
      obj_journals=issue_wf.journals
      #puts "=== obj_journals: " + obj_journals.awesome_inspect(:plain => false, :limit => false, :multiline => true)
      obj_journals.each do |journal|
        next unless journal.notes
        if ! journal.private_notes
            b_txt_note_new += "\n"   if ! b_txt_note_new.empty?
            b_txt_note_new += journal.notes
        end
      end  rescue nil
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'notes_exc_latest', b_txt_note_new)
      # Latest note, not stored yet.
      if issue_wf.notes
        if ! issue_wf.private_notes
            b_txt_note_new += "\n"   if ! b_txt_note_new.empty?
            b_txt_note_new += issue_wf.notes
            HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'note_latest', issue_wf.notes)
        end
      end
      # All notes
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'notes_all', b_txt_note_new)
      # Tracker:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'tracker_id',   issue_wf.tracker_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'tracker_name', issue_wf.tracker.try(:name))
      # Status:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'status_id',    issue_wf.status_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'status_name',  issue_wf.status.try(:name))
      # Priority:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'priority_id',   issue_wf.priority_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'priority_name', issue_wf.priority.try(:name))
      # Author:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'author_id',    issue_wf.author_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'author_name',  issue_wf.author.try(:name))
      # Assigned to:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'assigned_to_id',   issue_wf.assigned_to_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'assigned_to_name', issue_wf.assigned_to.try(:name))
      # Category:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'category_id', issue_wf.category.try(:name))
      new_category = IssueCategory.find_by_id(issue_wf.category) rescue nil
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'category_name', new_category.try(:name))

      # Fixed Version / Target version:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'target_version_id',   issue_wf.fixed_version_id)
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'target_version_name', issue_wf.fixed_version.try(:name))
      # Parent Issue:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'parent_issue_id', issue_wf.parent_id)
      # Start date:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'start_date', issue_wf.start_date)
      # Due date:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'due_date', issue_wf.due_date)
      # Estimated time:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'estimated_hours', issue_wf.estimated_hours)
      # Done %:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'done_ratio', issue_wf.done_ratio)
      # Is private:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'is_private', issue_wf.is_private)
      # Created on:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'created_on', issue_wf.created_on)
      # Updated on:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'updated_on', issue_wf.updated_on)
      # Closed on:
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'closed_on', issue_wf.closed_on)
      # All Custom Fields:
      issue_wf.custom_field_values.each do |custom_value|
        #field_name  = custom_value.custom_field.name
        field_id    = custom_value.custom_field.id
        field_value = custom_value.value
        field_key   = nil
        if field_value.is_a?(Array)
          # This Custom Field has multiple values enabled. Use only the first one for now.
          field_value = field_value[0]
        end
        #HrzLib::HrzLogger.debug_msg "CF #{field_id}: #{field_value}"
        #HrzLib::HrzLogger.debug_msg "CF #{field_id}: #{custom_value.inspect}"
        # For key/value custom fields (enumeration), get the actual value instead of the key
        if custom_value.custom_field.field_format == 'enumeration' && field_value.present?
          enumerations = custom_value.custom_field.enumerations
          #HrzLib::HrzLogger.debug_msg "CF enumerations #{field_id}: #{enumerations.inspect}"
          # Find the entry that matches the stored key (name)
          enum_entry = enumerations.find { |e| e.id == field_value.to_i }
          #HrzLib::HrzLogger.debug_msg "enum_entry CF-#{field_id} for val=#{field_value}: #{enum_entry.inspect}"
          if enum_entry && enum_entry.respond_to?(:name) && enum_entry.name.present?
            field_key   = field_value
            field_value = enum_entry.name
          end
        end
        # Create context Key from field name (all lowercase, replace blanks by underlines:
        #b_context_key = "cf_#{field_name.downcase.gsub(/\s+/, '_')}"
        #HrzLib::HrzTagFunctions.set_context_value('tkt_new', b_context_key,          field_value)
        HrzLib::HrzTagFunctions.set_context_value('tkt_new', "cf_id_#{field_id}",     field_value)
        HrzLib::HrzTagFunctions.set_context_value('tkt_new', "cf_key_id_#{field_id}", field_key)    unless field_key.nil?
      end
      # Watchers:
      #watchers_list = issue_wf.watcher_users.map(&:name).join(', ') rescue ''
      #HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'watchers', watchers_list)
      # Relations
      #relations_list = issue_wf.relations.map { |r| "#{r.relation_type}: ##{r.other_issue(self).id}" }.join(', ') rescue ''
      #HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'relations', relations_list)
      # Attachment names
      #attachments_list = issue_wf.attachments.map { |a| a.filename }.join(', ') rescue ''
      #HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'attachments', attachments_list)
      # Spent time, total:
      total_spent_hours = issue_wf.spent_hours rescue 0
      HrzLib::HrzTagFunctions.set_context_value('tkt_new', 'spent_hours', total_spent_hours)

      # ---------------------------------------------------------------------------------------------------------------------
      # b) old status, before the user changed anything in the ticket:
      if issue_wf.id && !issue_wf.new_record?   # Is there an old status? (It could be a new ticket.)
        # Project name / numeric ID / text ID ("my-project"):
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'project_id', issue_wf.project_id_was)
        old_project = Project.find_by_id(issue_wf.project_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'project_name', old_project.try(:name))
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'project_identifier', old_project.try(:identifier))
        # Ticket ID, Subject:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'issue_id', issue_wf.id)
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'subject',  issue_wf.subject_was)
        # Description:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'description', issue_wf.description_was)
        # Notes:
        b_txt_note_old = ''
        obj_journals = issue_wf.journals.where.not(id: issue_wf.current_journal.try(:id))
        obj_journals.each do |journal|
          next unless journal.notes
          if !journal.private_notes
            b_txt_note_old += "\n" if !b_txt_note_old.empty?
            b_txt_note_old += journal.notes
          end
        end rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'notes_all', b_txt_note_old)
        # Tracker
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'tracker_id', issue_wf.tracker_id_was)
        old_tracker = Tracker.find_by_id(issue_wf.tracker_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'tracker_name', old_tracker.try(:name))
        # Status:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'status_id', issue_wf.status_id_was)
        old_status = IssueStatus.find_by_id(issue_wf.status_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'status_name', old_status.try(:name))
        # Priority:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'priority_id', issue_wf.priority_id_was)
        old_priority = IssuePriority.find_by_id(issue_wf.priority_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'priority_name', old_priority.try(:name))
        # Author:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'author_id', issue_wf.author_id_was)
        old_author = User.find_by_id(issue_wf.author_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'author_name', old_author.try(:name))
        # Assigned to:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'assigned_to_id', issue_wf.assigned_to_id_was)
        old_assigned = User.find_by_id(issue_wf.assigned_to_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'assigned_to', old_assigned.try(:name))
        # Category:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'category_id', issue_wf.category_id_was)
        old_category = IssueCategory.find_by_id(issue_wf.category_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'category_name', old_category.try(:name))
        # Fixed Version / Target version:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'target_version_id', issue_wf.fixed_version_id_was)
        old_version = Version.find_by_id(issue_wf.fixed_version_id_was) rescue nil
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'target_version_name', old_version.try(:name))
        # Parent Issue:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'parent_issue_id', issue_wf.parent_id_was)
        # Start date:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'start_date', issue_wf.start_date_was)
        # Due date:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'due_date', issue_wf.due_date_was)
        # Estimated time:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'estimated_hours', issue_wf.estimated_hours_was)
        # Done %:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'done_ratio', issue_wf.done_ratio_was)
        # Is private:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'is_private', issue_wf.is_private_was)
        # Created on:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'created_on', issue_wf.created_on_was)
        # Updated on:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'updated_on', issue_wf.updated_on_was)
        # Closed on:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'closed_on', issue_wf.closed_on_was)
        # All Custom Fields:
        issue_wf.custom_field_values.each do |custom_value|
          #field_name = custom_value.custom_field.name
          field_id   = custom_value.custom_field.id
          old_custom_value = issue_wf.custom_value_for(field_id)
          field_value_old = old_custom_value.try(:value_was) || old_custom_value.try(:value)
          field_key_old   = nil
          if field_value_old.is_a?(Array)
            # This Custom Field has multiple values enabled. Use only the first one for now.
            field_value_old = field_value_old[0]
          end
          # For key/value custom fields (enumeration), get the actual value instead of the key
          if custom_value.custom_field.field_format == 'enumeration' && field_value_old.present?
            enumerations = custom_value.custom_field.enumerations
            #HrzLib::HrzLogger.debug_msg "CF enumerations #{field_id}: #{enumerations.inspect}"
            # Find the entry that matches the stored key (name)
            enum_entry = enumerations.find { |e| e.id == field_value_old.to_i }
            #HrzLib::HrzLogger.debug_msg "enum_entry CF-#{field_id} for val=#{field_value_old}: #{enum_entry.inspect}"
            if enum_entry && enum_entry.respond_to?(:name) && enum_entry.name.present?
              field_key       = field_value_old
              field_value_old = enum_entry.name
            end
          end
          # Create context Key from field name (all lowercase, replace blanks by underlines:
          #b_context_key = "cf_#{field_name.downcase.gsub(/\s+/, '_')}"
          #HrzLib::HrzTagFunctions.set_context_value('tkt_old', b_context_key,       field_value_old)
          HrzLib::HrzTagFunctions.set_context_value('tkt_old', "cf_id_#{field_id}",     field_value_old)
          HrzLib::HrzTagFunctions.set_context_value('tkt_old', "cf_key_id_#{field_id}", field_key_old)    unless field_key_old.nil?
        end
        # Watchers: Cannot deliver old status. If necessary: copy the code from above and deliver the new status here.
        #watchers_list = issue_wf.watcher_users.map(&:name).join(', ') rescue ''
        #HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'watchers', watchers_list)
        # Spent time: Same problem.
        #total_spent_hours = issue_wf.spent_hours rescue 0
        #HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'spent_hours', total_spent_hours)
        # We are currently updating an existing ticket:
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'is_new_ticket', false)
      else
        # New ticket. There are no old values.
        HrzLib::HrzTagFunctions.set_context_value('tkt_old', 'is_new_ticket', true)
      end
    end  # collect_issue_data_wf

  end  # module HrzAutoActionWf
end  # module HrzLib
