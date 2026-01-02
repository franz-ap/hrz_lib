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
        ticket_action1('ticket', q_new_ticket, (!q_new_ticket), hsh_action)
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
          HrzLogger.logger.debug_msg "action1: #{hsh_cond[:b_cond_question]}"
          if TagStringHelper::evaluate_hrz_condition (hsh_cond[:b_cond_hrz])
            HrzLogger.logger.debug_msg "action1: --> YES"
          else
            HrzLogger.logger.debug_msg "action1: --> NO"
            q_all_cond_true = false   # This one was not true. Stop checking.
          end
        end
      end
      return  if (! q_all_cond_true)  # Not all conditions met ... nothing to do here.

      # Perform the action steps
      hsh_action[:arr_steps].each do |hsh_step|
        HrzLogger.logger.debug_msg "action1 step: #{hsh_step[:b_title]}"
        # a) Preparation
        b_result_prep = TagStringHelper::str_hrz(hsh_step[:b_hrz_prep])
        HrzLogger.logger.debug_msg "action1: Preparation returned '#{b_result_prep}'. Should be empty. Discarding it."  if (! b_result_prep.empty?)
        # Do nothing else with the results of preparation and cleanup for now. No idea yet.
        # b) The step
        # TODO
        # c) Cleanup
        b_result_cln = TagStringHelper::str_hrz(hsh_step[:b_hrz_clean])
        HrzLogger.logger.debug_msg "action1: Cleanup returned '#{b_result_cln}'. Should be empty. Discarding it."  if (! b_result_cln.empty?)
      end
    end # action1


  end  # class HrzAutoAction
end  # module HrzLib
