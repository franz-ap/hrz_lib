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
        when 'get_param'
          hrz_strfunc_get_param(params)
        when 'tkt_old'
          hrz_strfunc_tkt_old(params)
        when 'tkt_new'
          hrz_strfunc_tkt_new(params)
        when 'set_param'
          hrz_strfunc_set_param(params)
        when 'show_info'
          HrzLogger.logger.info_msg (params.join(' '))
        when 'show_warning'
          HrzLogger.logger.warning_msg (params.join(' '))
        when 'show_error'
          HrzLogger.logger.error_msg (params.join(' '))
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
    
    # Analyze named parameters/arguments: array of strings -> hash
    # This utility method facilitates mixing position parameters with named parameters.
    # Position parameters must be at the beginning (if any), before any named parameters.
    # No further position parameters will be accepted after the first named parameter,
    #   they would be treated just like any 'other', remaining parameter, i.e. they would
    #   be collected in the 'other' array.
    # @param arr_param_names  [Array<String>] Array of strings with all defined argument/parameter names
    #                                         and optional alias names, separated by '/'.
    #                                         Example: 'nvl/default/if_empty' means: name 'nvl',
    #                                                  alias 1: 'default', alias 2: 'if_empty'
    # @param arr_param_values [Array<String> or Hash] Array of strings with parameter values, possibly
    #                                         prefixed by <par_name> '=' or ':' ... named parameter
    #                                         If you pass a Hash instead, it will be returned verbatim,
    #                                         wihtout any processing, just for extra flexibility of the calling method.
    # @param b_caller [String, optional]      Name of the caller. For documentation and for error messages.
    # @param n_pos_auto_assign [Integer]      0 <=  n <= arr_param_names.length. Only the first n
    #                                         anonymous/position values will be assigned to the given
    #                                         named parameters, the rest will be in the 'other' array.
    #                                         Optional. Missing or nil will be taken as "all of arr_param_names".
    #                                         Purpose: To limit the automatic assignment of position
    #                                                  parameters.
    #                                         0 means: no position parameters allowed, only named parameters.
    # @return [Hash] All parameters with their values plus an array 'other' with all remaining input values.
    #                Parameters, that were not given in arr_param_values have a nil value in the hash.
    # Examples:
    # * arr_param_names = ['main', 'sub', 'nvl/default']
    #   n_pos_auto_assign = 2
    #   arr_param_values = ['main:abc', 'sub:def', 'xy', 'z']   ->   { main: 'abc', sub: 'def', nvl: nil,  other: ['xy', 'z'] }
    # * arr_param_values = ['abc',      'def',     'xy', 'z']   ->   { main: 'abc', sub: 'def', nvl: nil,  other: ['xy', 'z'] }
    # * --"-- but with  n_pos=3                                 ->   { main: 'abc', sub: 'def', nvl: 'xy', other: ['z']       }
    # * --"-- with n_pos=4: error because n > [].length: "Invalid parameter n_pos_auto_assign, must be 0 <= n <= #{length}!"
    # More examples:
    # * n=2 ['abc', 'sub:def']     ->   { main: 'abc', sub: 'def', nvl: nil,   other: nil }
    # * n=2 ['abc', 'def']         ->   { main: 'abc', sub: 'def', nvl: nil,   other: nil }
    # * n=2 ['abc', 'nvl=def']     ->   { main: 'abc', sub: nil,   nvl: 'def', other: nil }
    # * n=2 ['abc', 'default=def'] ->   { main: 'abc', sub: nil,   nvl: 'def', other: nil }
    def self.analyze_named_params(arr_param_names,         # Array of strings with all defined parameter names.
                                  arr_param_values,        # Array of strings with parameter values or a hash.
                                  b_caller          = nil, # Name of the calling method.           Optional.
                                  n_pos_auto_assign = nil) # Position parameter auto assign limit. Optional.
      if arr_param_values.is_a?(Hash)
        result = arr_param_values  # Return the argument verbatim. No further processing. Ignore other arguments.
      else
        # Validate n_pos_auto_assign
        n_pos_auto_assign = arr_param_names.length   if n_pos_auto_assign.nil?
        if n_pos_auto_assign < 0 || n_pos_auto_assign > arr_param_names.length
          HrzLogger.error_msg("analyze_named_params#{b_caller.nil? || b_caller.empty? ? '' : ' of '}#{b_caller}: Invalid parameter n_pos_auto_assign = #{n_pos_auto_assign.to_s}, must be 0 <= n <= #{arr_param_names.length}!")
          return nil
        end

        # Build name-to-primary mapping (including aliases)
        name_map = {}
        arr_param_names.each do |name_spec|
          names = name_spec.split('/')
          primary = names.first
          names.each { |n| name_map[n] = primary }
        end

        # Initialize result hash
        result = {}
        arr_param_names.each do |name_spec|
          primary = name_spec.split('/').first
          result[primary.to_sym] = nil
        end
        result[:other] = []

        # Process parameter values
        j_pos_index         = 0
        q_named_encountered = false

        arr_param_values.each do |value|
          # Check if this is a named parameter (name=value or name:value)
          if value =~ /^([^=:]+)[:=](.*)$/
            param_name = $1
            param_value = $2

            # Find the primary name for this parameter
            primary = name_map[param_name]

            if primary
              result[primary.to_sym] = param_value
              q_named_encountered = true
            else
              # Unknown named parameter goes to 'other'
              result[:other] << value
            end
          else
            # Positional parameter
            if q_named_encountered
              # Once a named param was seen, all remaining values go to 'other'
              result[:other] << value
            elsif j_pos_index < n_pos_auto_assign
              # Assign to positional parameter
              primary = arr_param_names[j_pos_index].split('/').first
              result[primary.to_sym] = value
              j_pos_index += 1
            else
              # Exceeded positional limit, goes to 'other'
              result[:other] << value
            end
          end
        end

        # Clean up 'other' array - set to nil if empty
        result[:other] = nil if result[:other].empty?
      end
      result
    end  # analyze_named_params



    # get_param: Reads a parameter from the context.
    # Parameter names can be single (main) keys or main+sub keys. See also: get_context_value.
    #
    # Examples:                                       with price=1234 in the context / empty context:
    #                                                                           |             |
    #                                                                           V             V
    #   <HRZ get_param price>                  -> arr_args: ["price"]        -> 1234   /   <nothing>
    #   <HRZ get_param price, 0.0>             -> arr_args: ["price", "0.0"] -> 1234   /      0.0
    #   <HRZ get_param +>price</HRZ get_param> -> arr_args: ["price"]        -> 1234   /   <nothing>
    #
    #   Longer format, with named arguments instead of position parameters:
    #   <HRZ get_param name=price>                                           -> 1234   /   <nothing>
    #   <HRZ get_param name=price   default=0.0>                             -> 1234   /      0.0
    #   <HRZ get_param name="price" default="0.0">                           -> 1234   /      0.0
    #   <HRZ get_param +>name=price</HRZ get_param>                          -> 1234   /   <nothing>
    #   <HRZ get_param +>name="price"</HRZ get_param>                        -> 1234   /   <nothing>
    #
    # @param arr_args [Array<String> or Hash] Argument array: position parameters and/or named parameters. See analyze_named_params.
    #                                         Hash: Like the result of analyze_named_params. See there for details.
    #   arr_args[0] = 'key_main/main/name'     = (Main) parameter key name (required)
    #   arr_args[1] = 'nvl/default/if_missing' = Default value, in case the parameter/key does not exist (optional)
    #   arr_args[2..n]                           Any remaining arguments will be appended to the default value, joined by ' '
    #   Only available as named parameters:
    #                 'key_sub/sub'            = Sub-key name (optional)
    #                 'conversion/conv'        = Conversion of the result before returning it (optional)
    #                                            'to_i' ...... interprets leading characters in the result string as an integer and
    #                                                          returns that integer a as a string.
    #                                                          Use case: value "99 balloons" and you want to do a calculation.
    #                                                          If there is not a valid number at the start of str, "0" will be returned.
    #                                            'to_i_hex' .. Same as to_i, but for basis 16, i.e. hexadecimal numbers
    #                                            'to_i_oct' .. Same as to_i, but for basis  8, i.e. octal       numbers
    #                                            'to_i_bin' .. Same as to_i, but for basis 16, i.e. binary      numbers
    #                                            'to_f' ...... Same as to_i, but for floating point numbers
    #                                            'upper', 'upcase' ..... Turns all lowercase letters in the result into their uppercase counterparts.
    #                                            'lower', 'downcase' ... Turns all uppercase letters in the result into their lowercase counterparts.
    # @return [String] Parameter's value oder default value.
    def self.hrz_strfunc_get_param(arr_args)
      hsh_param  = analyze_named_params(['key_main/main/name', 'nvl/default/if_missing', 'key_sub/sub', 'conversion/conv'], arr_args, 'get_param', 2)
      b_key_main = hsh_param[:key_main]
      b_key_sub  = hsh_param[:key_sub]
      arr_other  = hsh_param[:other]
      b_nvl      = [hsh_param[:nvl], *arr_other].compact.join(' ')
      b_conv     = hsh_param[:conversion]

      if b_key_main.nil? || b_key_main.empty?
        b_msg = "get_param: At least a main parameter name is required."
        TagStringHelper.report_error(b_msg, { function: 'get_param', arr_args: arr_args })
        raise HrzError.new(b_msg, { function: 'get_param', arr_args: arr_args })
      end
      
      value = get_context_value(b_key_main, b_key_sub, b_nvl);
      if ! b_conv.nil?
        case b_conv
        when 'to_i'
          value = value.to_i
        when 'to_i_hex'
          value = value.to_i(16)
        when 'to_i_oct'
          value = value.to_i( 8)
        when 'to_i_bin'
          value = value.to_i( 2)
        when 'to_f'
          value = value.to_f
        when 'upper', 'upcase'
          value = value.upcase
        when 'lower', 'downcase'
          value = value.downcase
        else
          b_keys = [ b_key_main, (b_key_sub unless b_key_sub.nil? || b_key_sub.empty?) ].compact.join(".")
          b_msg  = "Unknown/unimplemented conversion '#{b_conv}' in HRZ get_param(#{b_keys})."
          HrzLogger.logger.warning_msg b_msg
          raise HrzError.new(b_msg, { function: 'get_param', arr_args: arr_args })
        end # case
      end
      value.to_s
    end  # hrz_strfunc_get_param


    # Convenience functions in connection with hrz_strfunc_get_param:
    # They behave exacly like get_param, but make their main key the sub key and set a new, fixed main key.
    # See hrz_strfunc_get_param for details.

    # Retrieve issue/ticket values, old status, i.e. before it was modified by a user.
    # @param arr_args [Array<String> or Hash] Argument array: position parameters and/or named parameters. See analyze_named_params.
    #                                         Hash: Like the result of analyze_named_params. See there for details.
    def hrz_strfunc_tkt_old(arr_args)
      hsh_param  = analyze_named_params(['key_main/main/name', 'nvl/default/if_missing', 'key_sub/sub', 'conversion/conv'], arr_args, 'get_param', 2)
      b_key_main = hsh_param[:key_main]
      hsh_param[:key_sub]  = b_key_main
      hsh_param[:key_main] = 'tkt_old'
      hrz_strfunc_get_param(hsh_param)
    end  # hrz_strfunc_tkt_old

    # Retrieve issue/ticket values, new status, i.e. after possible modifications by a user.
    # @param arr_args [Array<String> or Hash] Argument array: position parameters and/or named parameters. See analyze_named_params.
    #                                         Hash: Like the result of analyze_named_params. See there for details.
    def hrz_strfunc_tkt_new(arr_args)
      hsh_param  = analyze_named_params(['key_main/main/name', 'nvl/default/if_missing', 'key_sub/sub', 'conversion/conv'], arr_args, 'get_param', 2)
      b_key_main = hsh_param[:key_main]
      hsh_param[:key_sub]  = b_key_main
      hsh_param[:key_main] = 'tkt_new'
      hrz_strfunc_get_param(hsh_param)
    end  # hrz_strfunc_tkt_new



    # set_param: Stores a parameter in the context.
    # Parameter names can be single (main) keys or main+sub keys. See also: get_context_value.
    # Examples:
    #   <HRZ set_param total 1234>
    #   <HRZ set_param>custname John Doe</HRZ set_param>
    #   <HRZ set_param name="total" value=1234>
    #   <HRZ set_param>key_main="custname" John Doe</HRZ set_param>
    # See also hrz_strfunc_get_param for more examples.
    #
    # @param arr_args [Array<String> or Hash] Argument array: position parameters and/or named parameters. See analyze_named_params.
    #                                         Hash: Like the result of analyze_named_params. See there for details.
    #   arr_args[0] = 'key_main/main/name'  = (Main) parameter key name (required)
    #   arr_args[1] = 'value'               = The new value to be set. nil or '' are ok.
    #   arr_args[2] = 'key_sub/sub'         = Sub-key name (optional)
    #   arr_args[3..n]                        Any remaining array elments will be appended to the new value, separated by blanks.
    # @return [String] Empty string.
    def self.hrz_strfunc_set_param(arr_args)
      hsh_param  = analyze_named_params(['key_main/main/name', 'value', 'key_sub/sub'], arr_args, 'get_param', 2)
      b_key_main = hsh_param[:key_main]
      b_key_sub  = hsh_param[:key_sub]
      arr_other  = hsh_param[:other]
      b_value    = [hsh_param[:value], *arr_other].compact.join(' ')

      if b_key_main.nil? || b_key_main.empty?
        b_msg = "set_param: At least a main parameter name is required."
        TagStringHelper.report_error(b_msg, { function: 'set_param', arr_args: arr_args })
        raise HrzError.new(b_msg, { function: 'set_param', arr_args: arr_args })
      end
      
      set_context_value(b_key_main, b_key_sub, b_value);
      # Debug info:
      b_keys = [ b_key_main, (b_key_sub unless b_key_sub.nil? || b_key_sub.empty?) ].compact.join(".")
      HrzLogger.logger.debug_msg "set_param(#{b_keys} := #{b_value})"
      
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
    def self.get_context_value(key_main, key_sub, default = nil)
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



    # Appends the given value as a new element to an array in the conext.
    # @param key_main [Symbol, String] Main key (namespace). The only key, if you do not need a 2nd level.
    # @param key_sub  [Symbol, String] Sub key. Pass nil, if you want only a single level.
    # @param value    [Object] value: the new array element.
    def self.context_array_push(key_main, key_sub, value)
      arr = get_context_value(key_main, key_sub, nil);
      if arr.nil?
        arr = []
        set_context_value(key_main, key_sub, arr);
      end
      arr.push(value)   # This works and does, what we want, because arr is a reference to the array, not a copy.
    end  # context_array_push


  end  # class HrzTagFunctions
end  # module HrzLib
