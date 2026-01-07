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
# Purpose: Perform automatic actions according to the given text rules and conditions.

require_relative 'hrz_tag_parser'

module HrzLib
  B_MSG_USR_BEG           = 'HRZ Lib action1: '
  B_MSG_USR_WARN_NOT_DONE = 'Automatic action not performed. Please contact an admin.'

  class HrzAutoAction

    # Perform automatic actions for a given ticket
    # @param q_new_ticket [Boolean]     Are we currently working on a new ticket? true=yes, false=no
    # @param arr_actions  [Array<Hash>] Array of actions. Each action is a hash.
    #   Action hash:
    #    q_on_new_ticket    [Boolean]  Perform this action on new tickets?      true=yes, false=no
    #    q_on_ticket_update [Boolean]  Perform this action upon modification of an existing ticket.
    #    b_title            [String]   Title of this action.
    #    b_comment          [String]   Remarks about this action. Optional, for documentation.
    #    arr_cond           [Array<Hash>] Array of conditions that must be met (AND operations among all of them)
    #                                     before any of the steps below get performed.
    #                                     An empty array means: true, do it.
    #     Condition hash:
    #      b_cond_question    [String]      The condition as a text question, e.g.: "Is the ticket unassigned?"
    #      b_cond_hrz         [String]      Condition to be evalueated by evaluate_hrz_condition.
    #    arr_steps          [Array<Hash>] Array of steps to be perfomed, if the above conditions are met.
    #     Step hash:
    #      b_title            [String]   Title of this step.
    #      b_comment          [String]   Remarks about this step. Optional, for documentation.
    #      b_hrz_prep         [String]   <HRZ> tag string, that performs preparation actions. Optional.
    #        TODO step
    #      b_hrz_clean        [String]   <HRZ> tag string, that performs cleanup actions.     Optional.
    def self.ticket_actions(q_new_ticket,  # Are we currently working on a new ticket?
                            arr_actions)   # Array of actions to be performed.
      arr_actions.each do |hsh_action|
        action1('ticket', q_new_ticket, hsh_action)
      end
    end  # ticket_actions


    # Perform one action (possibly consisting of multiple steps).
    # @param b_m_obj_type [String]  Type of main object: 'ticket', ...
    # @param q_new_m_obj  [Boolean] Are we currently working on a new object (ticket, ...)? true=yes, false=no, update of existing object.
    # @param q_ticket_upd [Boolean]   Are we currently working on a ticket update? true=yes, false=no
    # @param hsh_action   [Hash]      Action hash. See ticket_actions for details.
    def self.action1(b_m_obj_type,  # Type of main object
                     q_new_m_obj,   # Are we currently working on a new main object (ticket, ...)?
                     hsh_action)    # Action hash.
      q_trigger = false
      case b_m_obj_type
        when 'ticket'
          q_trigger = (  q_new_m_obj   &&  hsh_action[:q_on_new_ticket]    == true) ||
                      ((!q_new_m_obj)  &&  hsh_action[:q_on_ticket_update] == true)
        else
          b_msg  = "Unknown/unimplemented action object type '#{b_m_obj_type}' in HrzAutoAction.action1."
      end # case
      return  if (! q_trigger)   # Nothing to do in this case

      # Ok, really something to do.
      HrzLogger.logger.debug_msg "== HrzAutoAction.action1: #{hsh_action[:b_title]} =="

      # Check all conditions:
      q_all_cond_true = true  # So far ...
      hsh_action[:arr_cond].each do |hsh_cond|
        if q_all_cond_true
          HrzLogger.logger.debug_msg "action1: Condition '#{hsh_cond[:b_cond_question]}'"
          begin
            if TagStringHelper::evaluate_hrz_condition (hsh_cond[:b_cond_hrz])
              HrzLogger.logger.debug_msg "action1: --> YES"
            else
              HrzLogger.logger.debug_msg "action1: --> NO"
              q_all_cond_true = false   # This one was not true. Stop checking.
            end
          rescue HrzLib::HrzError => e
            HrzLogger.logger.debug_msg "action1: Input b_cond_hrz: #{hsh_cond[:b_cond_hrz]}"
            HrzLogger.logger.debug_msg "✗ FAIL - Exception: #{e.message}"
            HrzLogger.logger.debug_msg "Error: #{HrzLib::TagStringHelper.errors_text}" if HrzLib::TagStringHelper.has_errors?
            HrzLogger.logger.warning_msg "#{B_MSG_USR_BEG}Could not solve '#{hsh_cond[:b_cond_question]}'. #{B_MSG_USR_WARN_NOT_DONE}"
            q_all_cond_true = false
          end
        end
      end
      return  if (! q_all_cond_true)  # Not all conditions met ... nothing to do here.

      # Perform the action steps
      begin
        b_title_step   = ''
        b_part_problem = ''
        b_hrz_problem  = ''
        hsh_action[:arr_steps].each do |hsh_step|
          b_title_step = hsh_step[:b_title]
          HrzLogger.logger.debug_msg "--- action1: step '#{b_title_step}' ---"
          # a) Preparation
          b_part_problem = 'preparation of step'
          b_hrz_problem  = hsh_step[:b_hrz_prep]
          b_result_prep  = TagStringHelper::str_hrz(hsh_step[:b_hrz_prep])
          HrzLogger.logger.debug_msg "action1: Preparation returned '#{b_result_prep}'. Should be empty. Discarding it."  if (! b_result_prep.empty?)
          # Do nothing else with the results of preparation and cleanup for now. No idea yet.
          # b) The main step
          b_part_problem = 'main step'
          b_hrz_problem  = ''
          b_todo         = hsh_step[:b_todo]
          if ! (b_todo.nil?  ||  b_todo.empty?)
             b_hrz_problem  = b_todo + ' opt: ' + hsh_step[:hsh_todo_opt].inspect
             perform_step_todo(hsh_step[:b_todo], hsh_step[:hsh_todo_opt])
          end # main step
          # c) Cleanup
          b_part_problem = 'cleanup of step'
          b_hrz_problem  = hsh_step[:b_hrz_clean]
          b_result_cln   = TagStringHelper::str_hrz(hsh_step[:b_hrz_clean])
          HrzLogger.logger.debug_msg "action1: Cleanup returned '#{b_result_cln}'. Should be empty. Discarding it."  if (! b_result_cln.empty?)
        end

      rescue Parslet::ParseFailed => e
        # Parse errors
        b_msg = "Parse error in action1, #{b_part_problem}, for input '#{b_hrz_problem}' at position #{e.parse_failure_cause.pos}: #{e.parse_failure_cause.to_s}"
        HrzLogger.logger.debug_msg "HRZ Tag str_hrz: #{b_msg} Parse tree: #{e.parse_failure_cause.ascii_tree}"
        HrzLogger.logger.warning_msg "#{B_MSG_USR_BEG}Could not perform #{b_part_problem} '#{b_title_step}'. #{B_MSG_USR_WARN_NOT_DONE}"
        #raise HrzError.new(b_msg, { cause: e })

      rescue HrzLib::HrzError => e
        HrzLogger.logger.debug_msg "action1 #{b_part_problem}: HrzError for input b_cond_hrz: #{b_hrz_problem}"
        HrzLogger.logger.debug_msg "✗ FAIL - Exception: #{e.message}"
        HrzLogger.logger.debug_msg "Error: #{HrzLib::TagStringHelper.errors_text}" if HrzLib::TagStringHelper.has_errors?
        HrzLogger.logger.warning_msg "#{B_MSG_USR_BEG}Could not perform #{b_part_problem} '#{b_title_step}'. #{B_MSG_USR_WARN_NOT_DONE}"

      rescue StandardError => e
        # Other error
        b_msg = "Std.error in action1, str_hrz: #{b_part_problem}, for input '#{b_hrz_problem}' processing HRZ tags: #{e.message}"
        HrzLogger.logger.debug_msg "HRZ Tag action1: #{b_msg}\n#{e.backtrace.join("\n")}"
        HrzLogger.logger.warning_msg "#{B_MSG_USR_BEG}Could not perform #{b_part_problem} '#{b_title_step}'. #{B_MSG_USR_WARN_NOT_DONE}"
        #raise HrzError.new(b_msg, { cause: e })
      end
    end # action1


    # Perfom the main part of the step, i.e. what needs to be done aside from preparation and cleanup.
    # @param b_todo   [String] Short name for the task to be performed: 'mk_issue_from_templ'  (The only one for now)
    # @param hsh_opt  [Hash]   Additional information about the above task.
    #   For task 'mk_issue_from_templ':
    #     :q_related         [Boolean] Make the new ticket related to the current main ticket (tkt_new)? true=yes, false=no, don't.
    #     :q_child           [Boolean] Make the new ticket a child of the current main ticket (tkt_new)? true=yes, false=no, don't.
    #     :issue_template_id [Integer] The ID of an existing issue to be used as template.
    #     :project_id        [Integer, String] The ID or identifier of the project.
    #                                          Optional. Pass it only, if you do not want the new ticket
    #                                          to be created where the main ticket resides.
    #     :q_only_1x         [Boolean] Do you want to avoid creating the 'same' ticket more than once (same b_issue_abbr and same parent/related)?
    #                                  true=yes false=no, don't care, create a new ticket with every call.
    #     :b_issue_abbr      [String]  A unique abbreviation for this kind of ticket. Required for q_only_1x.
    def self.perform_step_todo(b_todo, hsh_opt)
      # Remember the original recursion level.
      j_lvl_recu_orig = HrzLib::HrzTagFunctions.get_context_value('j_lvl_recu', nil, nil)
      return  if b_todo.nil? || b_todo.empty?
      # We will possibly start a new recursion in here, e.g. by creating an additionl ticket while we are still working on the other, main ticket.
      HrzLib::HrzTagFunctions.set_context_value('j_lvl_recu', nil, (j_lvl_recu_orig + 1))

      case b_todo
        when 'mk_issue_from_templ'
          if hsh_opt[:issue_template_id]
            q_related     = hsh_opt[:q_related]
            q_child       = hsh_opt[:q_child]
            q_only_1x     = hsh_opt[:q_only_1x]
            b_issue_abbr  = hsh_opt[:b_issue_abbr]
            project_id    = hsh_opt[:project_id]
            project_id    = HrzTagFunctions.get_context_value('tkt_new', 'project_id')  if project_id.nil?
            issue_main_id = HrzTagFunctions.get_context_value('tkt_new', 'issue_id')
            if q_only_1x && (b_issue_abbr.nil? || b_issue_abbr.empty?)
              HrzLogger.logger.debug_msg "perform_step_todo: Ignoring q_only_1x for task '#{b_todo}', because b_issue_abbr is empty."
              q_only_1x = false
            end
            q_creat_tkt = true
            b_suf       = ''
            if q_only_1x
              # See, if the requested ticket already exists. We want only 1 of them.
              b_suf    = " {#{b_issue_abbr}}"
              found_id = nil
              if q_related
                found_id = HrzLib::IssueHelper.find_related_with_subject(issue_main_id, b_suf)
              end # if q_related
              if q_child && (! found_id)
                found_id = HrzLib::IssueHelper.find_subtask_with_subject(42, 'testing')
              end # if q_child
              if found_id
                 HrzLogger.logger.info_msg "Ticket '#{b_issue_abbr}' exists already: ##{found_id}"
                 q_creat_tkt = false
              end
            end # if q_only_1x
            if q_creat_tkt
              template_issue_data = HrzLib::IssueHelper.get_issue(hsh_opt[:issue_template_id])
              if template_issue_data
                j_assignee      = HrzTagFunctions.get_context_value('tkt_prep', 'assigned_to_id')
                arr_watcher_ids = HrzTagFunctions.get_context_value('tkt_prep', 'arr_watcher_ids')
                new_options     = template_issue_data[:options]
                new_options[:parent_issue_id] = issue_main_id   if q_child
                new_issue_id = HrzLib::IssueHelper.mk_issue(
                                project_id,
                                template_issue_data[:b_subject] + b_suf,
                                template_issue_data[:b_desc],
                                j_assignee,
                                arr_watcher_ids,
                                new_options)
                if ! new_issue_id.nil?
                  if q_related
                    HrzLib::IssueHelper.create_relation(issue_main_id, new_issue_id, 'relates')
                  end
                  HrzLogger.logger.info_msg "Created #{q_related ? 'related ' : ''}#{q_child ? 'child ' : ''}ticket ##{new_issue_id}"
                end
              end # if template_issue_data
            end # if q_creat_tkt
          end # if hsh_opt[:issue_template_id]
        else
           HrzLogger.logger.debug_msg "perform_step_todo: task '#{b_todo}' is not implemented yet. Skipping it."
      end # case
    ensure
      # Restore the original recursion level
      HrzLib::HrzTagFunctions.set_context_value('j_lvl_recu', nil, j_lvl_recu_orig)
    end  # perform_step_todo


    # ------------------------------------------------------------------------------------------------------------------------------
    # Ticket preparation
    # ------------------------------------------------------------------------------------------------------------------------------

    # Clear prepared ticket assignee and watchers
    def self.tkt_prep_clear_assignee_watchers
       HrzTagFunctions.set_context_value('tkt_prep', 'assigned_to_id',  nil)
       HrzTagFunctions.set_context_value('tkt_prep', 'arr_watcher_ids', nil)
    end  # tkt_prep_clear_assignee_watchers



    # Set assignee and add watchers as a preparation for creating a ticket.
    # @param principal_id   [Integer] The ID of a Redmine group or user.
    # @param q_assignee_ena [Boolean] Enable setting/overwriting the assigne? true=yes, false=no
    # For Groups: The group's leader (if available) will be the assignee (if enabled above)
    #             All group members will be added as watchers.
    # For Users:  The user will be the (new) assignee, if enabled above (otherwise nothing will happen).
    def self.tkt_prep_set_assignee_add_watchers(principal_id, q_assignee_ena=true)
      hsh_grp_info = HrzLib::IssueHelper.get_group_members(principal_id)
      if hsh_grp_info
        if q_assignee_ena && hsh_grp_info[:leader_id]
          HrzTagFunctions.set_context_value('tkt_prep', 'assigned_to_id',  hsh_grp_info[:leader_id].to_s)
        end
        HrzTagFunctions.context_array_push( 'tkt_prep', 'arr_watcher_ids', hsh_grp_info[:arr_member_ids], true)
      end
      HrzLogger.logger.debug_msg 'Result tkt_prep_set_assignee_add_watchers: assignee=' + HrzTagFunctions.get_context_value('tkt_prep', 'assigned_to_id') + '  watchers: ' + HrzTagFunctions.get_context_value('tkt_prep', 'arr_watcher_ids').inspect
    end  # tkt_prep_set_assignee_add_watchers



  end  # class HrzAutoAction
end  # module HrzLib
