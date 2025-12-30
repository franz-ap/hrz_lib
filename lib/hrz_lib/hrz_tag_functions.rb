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
# Purpose: Implementation of HRZ tag functions

module HrzLib
  # Container class for all HRZ tag functions
  class HrzTagFunctions
    # Central dispatcher
    # @param b_function [String] Name of hrz_tag function to be called.
    # @param params [Array<String>] Array of string parameters
    # @return [String] Result
    def self.call_dispatcher(b_function, params = [])
      # Im Dry-Run-Modus: Dummy-Wert zurückgeben ohne Funktion auszuführen
      if TagStringHelper.dry_run_mode?
        HrzLogger.logger.debug_msg "Dry-run: call_dispatcher #{b_function}(#{params.inspect})"
        return "1"  # Standard-Dummy-Wert für Dry-Run
      end
      HrzLogger.logger.debug_msg "call_dispatcher ('#{b_function}, #{params})"

      case b_function
        when         'get_param'
          hrz_strfunc_get_param(params)
        when         'set_param'
          hrz_strfunc_set_param(params)
        else
          HrzLogger.logger.warning_msg "Unknown HRZ function: #{b_function}"
          raise HrzError.new("Unknown function: #{b_function}", { function: b_function })
      end  # case
    rescue HrzError
      # HrzError weitergeben
      raise
    rescue StandardError => e
      HrzLogger.logger.error_msg "Error in HRZ function #{b_function}: #{e.message}"
      raise HrzError.new("Error in function #{b_function}: #{e.message}",
                        { function: b_function, params: params, cause: e })
    end  # call_dispatcher


    
    # ============================================================================
    # Implementation of all those HRZ tag functions
    # ============================================================================
    
    # get_param: Reads a parameter from the conext.
    # Examples:                                       with price=1234 in the context / empty context:
    #                                                                           |            |
    #                                                                           V            V
    #   <HRZ get_param price>                  -> params: ["price"]        -> 1234   /   <nothing>
    #   <HRZ get_param price, 0.0>             -> params: ["price", "0.0"] -> 1234   /      0.0
    #   <HRZ get_param +>price</HRZ get_param> -> params: ["price"]        -> 1234   /   <nothing>
    #
    # @param params [Array<String>] Parameter-Array
    #   params[0] = Parameter name (required)
    #   params[1] = Default value, in case the parameter does not exist (optional)
    # @return [String] Parameter's value oder default value.
    def self.hrz_strfunc_get_param(params)
      param_name = params[0]
      default_value = params[1] || ""
      
      if param_name.nil? || param_name.empty?
        error_msg = "get_param: parameter name is required"
        TagStringHelper.report_error(error_msg, { function: 'get_param', params: params })
        raise HrzError.new(error_msg, { function: 'get_param', params: params })
      end
      
      # Context abrufen
      context = Thread.current[:hrz_context] || {}
      value = context[param_name.to_sym]
      
      if value.nil?
        HrzLogger.logger.debug_msg "Parameter '#{param_name}' not found, using default: '#{default_value}'"
        default_value
      else
        value.to_s
      end
    end  # hrz_strfunc_get_param


    
    # set_param: Stores a parameter in the context.
    # Examples:
    #   <HRZ set_param total 1234>
    #   <HRZ set_param>cuname John Doe</HRZ set_param>
    #
    # @param params [Array<String>] Parameter-Array
    #   params[0]    = Parameter name (required)
    #   params[1..n] = New value for this parameter, all array elments will be concatenated into a single string, separated by single blanks.
    # @return [String] Empty string
    def self.hrz_strfunc_set_param(params)
      param_name  = params[0]
      param_value = params[1..-1].join(" ")    # join calls to_s for each array element.
      
      if param_name.nil? || param_name.empty?
        error_msg = "set_param: parameter name is required"
        TagStringHelper.report_error(error_msg, { function: 'set_param', params: params })
        raise HrzError.new(error_msg, { function: 'set_param', params: params })
      end
      
      # Put the new value into the context
      Thread.current[:hrz_context] ||= {}
      Thread.current[:hrz_context][param_name.to_sym] = param_value
      
      HrzLogger.logger.debug_msg "Parameter '#{param_name}' set to '#{param_value}'"
      
      # set_param never returns a text, only this empty string:
      ""
    end  # hrz_strfunc_set_param


    
    # ============================================================================
    # Context management utilities
    # ============================================================================
    
    # Initializes the context.
    # @param initial_context [Hash] Initial context, optional.
    def self.initialize_context(initial_context = {})
      Thread.current[:hrz_context] = initial_context.dup
    end  # initialize_context
    


    # Returns the current context.
    # @return [Hash] current context.
    def self.current_context
      Thread.current[:hrz_context] || {}
    end  # current_context
    


    # Clears the context, e.g. at the end of a session.
    def self.clear_context
      Thread.current[:hrz_context] = nil
    end  # clear_context
    


    # Sets a value in the context, overwriting the previous value, in case a parameter/key already existed.
    # Main keys can be seen as namespaces. The same sub key can exist in more than one, with different values.
    # @param key_main [Symbol, String] Main key (namespace). The only key, if you do not need a 2nd level.
    # @param key_sub  [Symbol, String] Sub key. Pass nil, if you want only a single level.
    # @param value    [Object] value
    def self.set_context_value(key_main, key_sub, value)
      Thread.current[:hrz_context] ||= {}

      if key_sub.nil?
        # Simple key, single level.
        Thread.current[:hrz_context][key_main.to_sym] = value
      else
        # Two levels
        Thread.current[:hrz_context][key_main.to_sym] ||= {}
        Thread.current[:hrz_context][key_main.to_sym][key_sub.to_sym] = value
      end
    end  # set_context_value
    


    # Reads a value from the context.
    # @param key_main [Symbol, String] Main key (namespace). The only key, if you do not need a 2nd level.
    # @param key_sub  [Symbol, String] Sub key. Pass nil, if you want only a single level. If you do that for a 2-level key,
    #                                  you will receive a hash of all parameters in that "namespace".
    # @param default [Object] Default value, optional. Nil, if not passed in. Will be used, if no such key exists.
    # @return [Object] value from the context oder the default value.
    def self.get_context_value(key, default = nil)
      context = Thread.current[:hrz_context] || {}

      if key_sub.nil?
        # Simple key, single level.
        context[key_main.to_sym] || default
      else
        # Zweistufiger Key
        main_hash = context[key_main.to_sym]
        return default unless main_hash.is_a?(Hash)
        main_hash[key_sub.to_sym] || default
      end
    end  # get_context_value

  end  # class HrzTagFunctions
end  # module HrzLib
