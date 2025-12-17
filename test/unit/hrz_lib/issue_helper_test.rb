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
# Purpose: Unit tests for HrzLib::IssueHelper module.
#
# * Issue creation: basic, with assignee, watchers, options, custom fields
# * File attachments, error handling
# * Relations: All relation types (relates, blocks, precedes, etc.)
# * Issue updates: subject, notes, custom fields
# * Notes/comments: normal, private, with attribute changes
# * Watchers: add, remove, get, check, set (multiple)
# * Time entries: create, update, delete, get entries, get total hours
# * Retrieve user time entries: daily hours, range hours grouped



require_relative '../test_helper'

class IssueHelperTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses, :issues, 
           :enumerations, :roles, :members, :member_roles

  def setup
    @project = Project.find(1)
    @user = User.find(2)
    User.current = @user
  end

  def teardown
    User.current = nil
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # mk_issue tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should create basic issue" do
    issue_id = HrzLib::IssueHelper.mk_issue(
      @project.id,
      'Test Issue',
      'Test Description'
    )
    
    assert_not_nil issue_id
    issue = Issue.find(issue_id)
    assert_equal 'Test Issue', issue.subject
    assert_equal 'Test Description', issue.description
    assert_equal @project.id, issue.project_id
  end

  test "should create issue with assignee" do
    assignee = User.find(3)
    issue_id = HrzLib::IssueHelper.mk_issue(
      @project.id,
      'Assigned Issue',
      'Test',
      assignee.id
    )
    
    assert_not_nil issue_id
    issue = Issue.find(issue_id)
    assert_equal assignee.id, issue.assigned_to_id
  end

  test "should create issue with watchers" do
    watcher1 = User.find(3)
    watcher2 = User.find(4)
    
    issue_id = HrzLib::IssueHelper.mk_issue(
      @project.id,
      'Watched Issue',
      'Test',
      nil,
      [watcher1.id, watcher2.id]
    )
    
    assert_not_nil issue_id
    issue = Issue.find(issue_id)
    assert_includes issue.watcher_users.map(&:id), watcher1.id
    assert_includes issue.watcher_users.map(&:id), watcher2.id
  end

  test "should create issue with options" do
    tracker = @project.trackers.first
    status = IssueStatus.find(2)
    priority = IssuePriority.find(5)
    
    issue_id = HrzLib::IssueHelper.mk_issue(
      @project.id,
      'Issue with Options',
      'Test',
      nil,
      [],
      tracker_id: tracker.id,
      status_id: status.id,
      priority_id: priority.id,
      due_date: '2025-12-31',
      estimated_hours: 8
    )
    
    assert_not_nil issue_id
    issue = Issue.find(issue_id)
    assert_equal tracker.id, issue.tracker_id
    assert_equal status.id, issue.status_id
    assert_equal priority.id, issue.priority_id
    assert_equal Date.parse('2025-12-31'), issue.due_date
    assert_equal 8.0, issue.estimated_hours
  end

  test "should create issue with custom fields" do
    cf = IssueCustomField.create!(
      name: 'Test Field',
      field_format: 'string',
      is_for_all: true
    )
    @project.trackers.first.custom_field_ids = [cf.id]
    
    issue_id = HrzLib::IssueHelper.mk_issue(
      @project.id,
      'Issue with CF',
      'Test',
      nil,
      [],
      custom_fields: {cf.id => 'Test Value'}
    )
    
    assert_not_nil issue_id
    issue = Issue.find(issue_id)
    assert_equal 'Test Value', issue.custom_field_value(cf)
  end

  test "should return nil for nonexistent project" do
    issue_id = HrzLib::IssueHelper.mk_issue(
      99999,
      'Test',
      'Test'
    )
    
    assert_nil issue_id
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # attach_file tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should attach file to issue" do
    issue = Issue.find(1)
    
    # Create a temporary test file
    temp_file = Tempfile.new(['test', '.txt'])
    temp_file.write('Test content')
    temp_file.close
    
    attachment_id = HrzLib::IssueHelper.attach_file(
      issue.id,
      temp_file.path,
      filename: 'test.txt',
      description: 'Test attachment'
    )
    
    assert_not_nil attachment_id
    attachment = Attachment.find(attachment_id)
    assert_equal 'test.txt', attachment.filename
    assert_equal 'Test attachment', attachment.description
    assert_equal issue, attachment.container
    
  ensure
    temp_file.unlink if temp_file
  end

  test "should return nil for nonexistent file" do
    issue = Issue.find(1)
    
    attachment_id = HrzLib::IssueHelper.attach_file(
      issue.id,
      '/nonexistent/file.txt'
    )
    
    assert_nil attachment_id
  end

  test "should return nil for nonexistent issue" do
    temp_file = Tempfile.new(['test', '.txt'])
    temp_file.write('Test')
    temp_file.close
    
    attachment_id = HrzLib::IssueHelper.attach_file(
      99999,
      temp_file.path
    )
    
    assert_nil attachment_id
    
  ensure
    temp_file.unlink if temp_file
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # create_relation tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should create relates relation" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    
    relation_id = HrzLib::IssueHelper.create_relation(
      issue1.id,
      issue2.id,
      'relates'
    )
    
    assert_not_nil relation_id
    relation = IssueRelation.find(relation_id)
    assert_equal issue1.id, relation.issue_from_id
    assert_equal issue2.id, relation.issue_to_id
    assert_equal 'relates', relation.relation_type
  end

  test "should create blocks relation" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    
    relation_id = HrzLib::IssueHelper.create_relation(
      issue1.id,
      issue2.id,
      'blocks'
    )
    
    assert_not_nil relation_id
    relation = IssueRelation.find(relation_id)
    assert_equal 'blocks', relation.relation_type
  end

  test "should create precedes relation with delay" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    
    relation_id = HrzLib::IssueHelper.create_relation(
      issue1.id,
      issue2.id,
      'precedes',
      delay: 5
    )
    
    assert_not_nil relation_id
    relation = IssueRelation.find(relation_id)
    assert_equal 'precedes', relation.relation_type
    assert_equal 5, relation.delay
  end

  test "should return nil for invalid relation type" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    
    relation_id = HrzLib::IssueHelper.create_relation(
      issue1.id,
      issue2.id,
      'invalid_type'
    )
    
    assert_nil relation_id
  end

  test "should return existing relation id if already exists" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    
    first_id = HrzLib::IssueHelper.create_relation(
      issue1.id,
      issue2.id,
      'relates'
    )
    
    second_id = HrzLib::IssueHelper.create_relation(
      issue1.id,
      issue2.id,
      'relates'
    )
    
    assert_equal first_id, second_id
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # update_issue tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should update issue subject" do
    issue = Issue.find(1)
    original_subject = issue.subject
    
    success = HrzLib::IssueHelper.update_issue(
      issue.id,
      subject: 'Updated Subject'
    )
    
    assert success
    issue.reload
    assert_equal 'Updated Subject', issue.subject
    assert_not_equal original_subject, issue.subject
  end

  test "should update issue with notes" do
    issue = Issue.find(1)
    
    success = HrzLib::IssueHelper.update_issue(
      issue.id,
      {done_ratio: 50},
      notes: 'Progress update'
    )
    
    assert success
    issue.reload
    assert_equal 50, issue.done_ratio
    assert_not_nil issue.journals.last
    assert_equal 'Progress update', issue.journals.last.notes
  end

  test "should update custom fields" do
    issue = Issue.find(1)
    cf = IssueCustomField.create!(
      name: 'Update Test Field',
      field_format: 'string',
      is_for_all: true
    )
    issue.project.trackers.first.custom_field_ids = [cf.id]
    
    success = HrzLib::IssueHelper.update_issue(
      issue.id,
      custom_fields: {cf.id => 'New Value'}
    )
    
    assert success
    issue.reload
    assert_equal 'New Value', issue.custom_field_value(cf)
  end

  test "should return false for nonexistent issue" do
    success = HrzLib::IssueHelper.update_issue(
      99999,
      subject: 'Test'
    )
    
    assert_not success
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # add_comment tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should add comment to issue" do
    issue = Issue.find(1)
    initial_journal_count = issue.journals.count
    
    journal_id = HrzLib::IssueHelper.add_comment(
      issue.id,
      'Test comment'
    )
    
    assert_not_nil journal_id
    issue.reload
    assert_equal initial_journal_count + 1, issue.journals.count
    assert_equal 'Test comment', issue.journals.last.notes
  end

  test "should add private comment" do
    issue = Issue.find(1)
    
    journal_id = HrzLib::IssueHelper.add_comment(
      issue.id,
      'Private note',
      private: true
    )
    
    assert_not_nil journal_id
    journal = Journal.find(journal_id)
    assert journal.private_notes
  end

  test "should add comment with attribute changes" do
    issue = Issue.find(1)
    new_status = IssueStatus.find(2)
    
    journal_id = HrzLib::IssueHelper.add_comment(
      issue.id,
      'Status changed',
      attribute_changes: {status_id: new_status.id}
    )
    
    assert_not_nil journal_id
    issue.reload
    assert_equal new_status.id, issue.status_id
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # Watcher tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should add watcher to issue" do
    issue = Issue.find(1)
    user = User.find(3)
    
    success = HrzLib::IssueHelper.add_watcher(issue.id, user.id)
    
    assert success
    assert issue.watched_by?(user)
  end

  test "should return true if watcher already exists" do
    issue = Issue.find(1)
    user = User.find(3)
    
    HrzLib::IssueHelper.add_watcher(issue.id, user.id)
    success = HrzLib::IssueHelper.add_watcher(issue.id, user.id)
    
    assert success
  end

  test "should add multiple watchers" do
    issue = Issue.find(1)
    users = [3, 4, 5]
    
    result = HrzLib::IssueHelper.add_watchers(issue.id, users)
    
    assert_equal 3, result[:success]
    assert_empty result[:failed]
    users.each do |user_id|
      assert issue.watched_by?(User.find(user_id))
    end
  end

  test "should remove watcher from issue" do
    issue = Issue.find(1)
    user = User.find(3)
    
    HrzLib::IssueHelper.add_watcher(issue.id, user.id)
    success = HrzLib::IssueHelper.remove_watcher(issue.id, user.id)
    
    assert success
    assert_not issue.watched_by?(user)
  end

  test "should remove multiple watchers" do
    issue = Issue.find(1)
    users = [3, 4, 5]
    
    HrzLib::IssueHelper.add_watchers(issue.id, users)
    result = HrzLib::IssueHelper.remove_watchers(issue.id, users)
    
    assert_equal 3, result[:success]
    assert_empty result[:failed]
  end

  test "should get watchers" do
    issue = Issue.find(1)
    user1 = User.find(3)
    user2 = User.find(4)
    
    HrzLib::IssueHelper.add_watchers(issue.id, [user1.id, user2.id])
    watchers = HrzLib::IssueHelper.get_watchers(issue.id)
    
    assert_not_nil watchers
    assert_equal 2, watchers.length
    assert_includes watchers.map { |w| w[:id] }, user1.id
    assert_includes watchers.map { |w| w[:id] }, user2.id
  end

  test "should check if user is watching" do
    issue = Issue.find(1)
    user = User.find(3)
    
    assert_not HrzLib::IssueHelper.is_watching?(issue.id, user.id)
    
    HrzLib::IssueHelper.add_watcher(issue.id, user.id)
    
    assert HrzLib::IssueHelper.is_watching?(issue.id, user.id)
  end

  test "should set watchers" do
    issue = Issue.find(1)
    old_users = [3, 4]
    new_users = [5, 6]
    
    HrzLib::IssueHelper.add_watchers(issue.id, old_users)
    success = HrzLib::IssueHelper.set_watchers(issue.id, new_users)
    
    assert success
    assert_not issue.watched_by?(User.find(3))
    assert_not issue.watched_by?(User.find(4))
    assert issue.watched_by?(User.find(5))
    assert issue.watched_by?(User.find(6))
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # Related issue search tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should find issue ID in related issue subject" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    issue2.update!(subject: 'Test related issue with keyword')
    
    HrzLib::IssueHelper.create_relation(issue1.id, issue2.id, 'relates')
    
    found_id = HrzLib::IssueHelper.find_related_with_subject(issue1.id, 'keyword')
    
    assert_not_nil found_id
    assert_equal issue2.id, found_id
  end

  test "should return nil when text not found in related issues" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    issue2.update!(subject: 'Test related issue')
    
    HrzLib::IssueHelper.create_relation(issue1.id, issue2.id, 'relates')
    
    found_id = HrzLib::IssueHelper.find_related_with_subject(issue1.id, 'nonexistent')
    
    assert_nil found_id
  end

  test "should return nil when no related issues exist" do
    issue = Issue.find(1)
    
    found_id = HrzLib::IssueHelper.find_related_with_subject(issue.id, 'keyword')
    
    assert_nil found_id
  end

  test "should find issue ID across all relation types" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    issue3 = Issue.find(3)
    
    issue2.update!(subject: 'Blocked issue with target')
    issue3.update!(subject: 'Related issue without target')
    
    HrzLib::IssueHelper.create_relation(issue1.id, issue2.id, 'blocks')
    HrzLib::IssueHelper.create_relation(issue1.id, issue3.id, 'relates')
    
    found_id = HrzLib::IssueHelper.find_related_with_subject(issue1.id, 'target')
    
    assert_not_nil found_id
    assert_equal issue2.id, found_id
  end

  test "should find issue ID case insensitive in related issues" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    issue2.update!(subject: 'Test KEYWORD Issue')
    
    HrzLib::IssueHelper.create_relation(issue1.id, issue2.id, 'relates')
    
    found_id = HrzLib::IssueHelper.find_related_with_subject(issue1.id, 'keyword')
    
    assert_not_nil found_id
    assert_equal issue2.id, found_id
  end

  test "should return nil for nonexistent issue in find related" do
    found_id = HrzLib::IssueHelper.find_related_with_subject(99999, 'keyword')
    
    assert_nil found_id
  end

  # Outer method tests (has_related_with_subject?)

  test "should return true when related issue has keyword" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    issue2.update!(subject: 'Test related issue with keyword')
    
    HrzLib::IssueHelper.create_relation(issue1.id, issue2.id, 'relates')
    
    result = HrzLib::IssueHelper.has_related_with_subject?(issue1.id, 'keyword')
    
    assert result
  end

  test "should return false when no related issues have keyword" do
    issue1 = Issue.find(1)
    issue2 = Issue.find(2)
    issue2.update!(subject: 'Test related issue')
    
    HrzLib::IssueHelper.create_relation(issue1.id, issue2.id, 'relates')
    
    result = HrzLib::IssueHelper.has_related_with_subject?(issue1.id, 'nonexistent')
    
    assert_not result
  end

  test "should return false when no related issues exist" do
    issue = Issue.find(1)
    
    result = HrzLib::IssueHelper.has_related_with_subject?(issue.id, 'keyword')
    
    assert_not result
  end

  test "should return nil for nonexistent issue in has related" do
    result = HrzLib::IssueHelper.has_related_with_subject?(99999, 'keyword')
    
    assert_nil result
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # Sub-task search tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should find subtask ID with keyword in subject" do
    parent = Issue.find(1)
    child = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'Subtask with keyword here',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(parent.id, 'keyword')
    
    assert_not_nil found_id
    assert_equal child.id, found_id
  end

  test "should return nil when text not found in subtasks" do
    parent = Issue.find(1)
    child = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'Subtask without target text',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(parent.id, 'keyword')
    
    assert_nil found_id
  end

  test "should return nil when no subtasks exist" do
    issue = Issue.find(1)
    
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(issue.id, 'keyword')
    
    assert_nil found_id
  end

  test "should find first matching subtask ID" do
    parent = Issue.find(1)
    
    child1 = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'First subtask',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    child2 = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'Second subtask with target',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(parent.id, 'target')
    
    assert_not_nil found_id
    assert_equal child2.id, found_id
  end

  test "should find subtask ID case insensitive" do
    parent = Issue.find(1)
    child = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'Subtask with KEYWORD',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(parent.id, 'keyword')
    
    assert_not_nil found_id
    assert_equal child.id, found_id
  end

  test "should return nil for nonexistent issue in find subtask" do
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(99999, 'keyword')
    
    assert_nil found_id
  end

  test "should find subtask ID with partial text match" do
    parent = Issue.find(1)
    child = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'This is a long subtask subject with embedded keyword text',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    found_id = HrzLib::IssueHelper.find_subtask_with_subject(parent.id, 'embedded keyword')
    
    assert_not_nil found_id
    assert_equal child.id, found_id
  end

  # Outer method tests (has_subtask_with_subject?)

  test "should return true when subtask has keyword" do
    parent = Issue.find(1)
    child = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'Subtask with keyword here',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    result = HrzLib::IssueHelper.has_subtask_with_subject?(parent.id, 'keyword')
    
    assert result
  end

  test "should return false when no subtasks have keyword" do
    parent = Issue.find(1)
    child = Issue.create!(
      project: parent.project,
      tracker: parent.tracker,
      author: User.current,
      subject: 'Subtask without target text',
      parent_issue_id: parent.id,
      status: IssueStatus.default,
      priority: IssuePriority.default
    )
    
    result = HrzLib::IssueHelper.has_subtask_with_subject?(parent.id, 'keyword')
    
    assert_not result
  end

  test "should return false when no subtasks exist" do
    issue = Issue.find(1)
    
    result = HrzLib::IssueHelper.has_subtask_with_subject?(issue.id, 'keyword')
    
    assert_not result
  end

  test "should return nil for nonexistent issue in has subtask" do
    result = HrzLib::IssueHelper.has_subtask_with_subject?(99999, 'keyword')
    
    assert_nil result
  end

  # ------------------------------------------------------------------------------------------------------------------------------
  # Time entry tests
  # ------------------------------------------------------------------------------------------------------------------------------

  test "should create time entry" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    
    time_entry_id = HrzLib::IssueHelper.create_time_entry(
      issue.id,
      2.5,
      activity_id: activity.id,
      comments: 'Development work'
    )
    
    assert_not_nil time_entry_id
    time_entry = TimeEntry.find(time_entry_id)
    assert_equal 2.5, time_entry.hours
    assert_equal 'Development work', time_entry.comments
    assert_equal activity.id, time_entry.activity_id
  end

  test "should create time entry with custom date" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    date = Date.parse('2025-12-10')
    
    time_entry_id = HrzLib::IssueHelper.create_time_entry(
      issue.id,
      4.0,
      activity_id: activity.id,
      spent_on: date
    )
    
    assert_not_nil time_entry_id
    time_entry = TimeEntry.find(time_entry_id)
    assert_equal date, time_entry.spent_on
  end

  test "should update time entry" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    
    time_entry_id = HrzLib::IssueHelper.create_time_entry(
      issue.id,
      2.0,
      activity_id: activity.id
    )
    
    success = HrzLib::IssueHelper.update_time_entry(
      time_entry_id,
      hours: 3.5,
      comments: 'Updated'
    )
    
    assert success
    time_entry = TimeEntry.find(time_entry_id)
    assert_equal 3.5, time_entry.hours
    assert_equal 'Updated', time_entry.comments
  end

  test "should delete time entry" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    
    time_entry_id = HrzLib::IssueHelper.create_time_entry(
      issue.id,
      2.0,
      activity_id: activity.id
    )
    
    success = HrzLib::IssueHelper.delete_time_entry(time_entry_id)
    
    assert success
    assert_nil TimeEntry.find_by(id: time_entry_id)
  end

  test "should get time entries for issue" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    
    HrzLib::IssueHelper.create_time_entry(issue.id, 2.0, activity_id: activity.id)
    HrzLib::IssueHelper.create_time_entry(issue.id, 3.0, activity_id: activity.id)
    
    entries = HrzLib::IssueHelper.get_time_entries(issue.id)
    
    assert_not_nil entries
    assert entries.length >= 2
  end

  test "should get total hours for issue" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    
    # Clear existing time entries
    issue.time_entries.destroy_all
    
    HrzLib::IssueHelper.create_time_entry(issue.id, 2.5, activity_id: activity.id)
    HrzLib::IssueHelper.create_time_entry(issue.id, 3.5, activity_id: activity.id)
    
    total = HrzLib::IssueHelper.get_total_hours(issue.id)
    
    assert_equal 6.0, total
  end

  test "should get user daily hours" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    user = User.find(2)
    
    with_user(user) do
      HrzLib::IssueHelper.create_time_entry(
        issue.id,
        2.5,
        activity_id: activity.id,
        spent_on: Date.today
      )
      
      HrzLib::IssueHelper.create_time_entry(
        issue.id,
        3.0,
        activity_id: activity.id,
        spent_on: Date.today
      )
    end
    
    result = HrzLib::IssueHelper.get_user_daily_hours(user.id, Date.today)
    
    assert_not_nil result
    assert result[:total_hours] >= 5.5
    assert_equal Date.today.to_s, result[:date]
  end

  test "should get user hours range" do
    issue = Issue.find(1)
    activity = TimeEntryActivity.first
    user = User.find(2)
    from_date = Date.today - 7
    to_date = Date.today
    
    with_user(user) do
      HrzLib::IssueHelper.create_time_entry(
        issue.id,
        2.0,
        activity_id: activity.id,
        spent_on: from_date
      )
      
      HrzLib::IssueHelper.create_time_entry(
        issue.id,
        3.0,
        activity_id: activity.id,
        spent_on: to_date
      )
    end
    
    result = HrzLib::IssueHelper.get_user_hours_range(user.id, from_date, to_date)
    
    assert_not_nil result
    assert result[:total_hours] >= 5.0
    assert_equal from_date.to_s, result[:from_date]
    assert_equal to_date.to_s, result[:to_date]
  end

  test "should get time entry activities" do
    activities = HrzLib::IssueHelper.get_time_entry_activities
    
    assert_not_nil activities
    assert activities.length > 0
    assert activities.first.key?(:id)
    assert activities.first.key?(:name)
  end
end