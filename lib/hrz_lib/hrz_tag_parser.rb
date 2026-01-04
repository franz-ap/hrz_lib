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
# Purpose: Parser and processor for HRZ tags in text strings

require          'parslet'                # https://kschiess.github.io/parslet
require          'parslet/convenience'    # https://github.com/kschiess/parslet
require_relative 'hrz_tag_functions'

module HrzLib
  # Color codes for puts console output
  B_ANSI_RESET_COLOR           = "\e[0m"
  B_ANSI_YELLOW_BGCOLOR_STD    = "\e[43m"
  B_ANSI_YELLOW_BGCOLOR_BRIGHT = "\e[103m"
  B_ANSI_WHITE_ON_RED_BGCOLOR  = "\e[37;41m"

  # Logger wrapper, enabling standalone tests without Rails.
  class HrzLogger
    def initialize
       @q_debug_enabled = false  # Default: Debug off
    end


    # Enable or disable debug output.
    # @param q_enabled [Boolean] Debug output enabled from now on (true) or not (false).
    def self.debug_enable(q_enabled)
       @q_debug_enabled = q_enabled
    end  # debug_enable


    # Is debug output enabled?
    def self.debug_enabled?
      @q_debug_enabled
    end  # debug_enabled?


    # Issue a general debug message.
    # @param b_msg [String] The debug message.
    def self.debug_msg(b_msg)
      return unless @q_debug_enabled
      puts '[DEBUG] ' + B_ANSI_YELLOW_BGCOLOR_STD + b_msg + B_ANSI_RESET_COLOR
      HrzTagFunctions.context_array_push('hrz_msgs', 'debug', b_msg)
    end  # debug_msg


    # Issue a transform debug message, at the beinning of the transformation.
    # @param b_rule [String] Name of the rule.
    # @param b_msg  [String] The debug message.
    def self.transform_beg(b_rule, b_msg)
      HrzLogger.debug_msg("Transform '#{b_rule}': #{b_msg}")
    end  # transform_beg


    # Issue a transform debug message, at the end of the transformation.
    # @param b_msg [String] The debug message: result.
    def self.transform_res(b_msg)
      HrzLogger.debug_msg("  ----->  #{b_msg}")
    end  # transform_res


    # Issue a general info message.
    # @param b_msg [String] The info message.
    def self.info_msg(b_msg)
      puts "[INFO] #{b_msg}"
      HrzTagFunctions.context_array_push('hrz_msgs', 'info', b_msg)
    end  # info_msg


    # Issue a general warning message.
    # @param b_msg [String] The warning message.
    def self.warning_msg(b_msg)
      puts '[WARN] ' + B_ANSI_YELLOW_BGCOLOR_BRIGHT + b_msg + B_ANSI_RESET_COLOR
      HrzTagFunctions.context_array_push('hrz_msgs', 'warning', b_msg)
    end  # warning_msg


    # Issue a general error message.
    # @param b_msg [String] The error message.
    def self.error_msg(b_msg)
      puts '[ERROR] '+ B_ANSI_WHITE_ON_RED_BGCOLOR + b_msg + B_ANSI_RESET_COLOR
      HrzTagFunctions.context_array_push('hrz_msgs', 'error', b_msg)
    end  # error_msg
    

    # Issue a general, severe error message, that will abort the ticket modification.
    # @param b_msg [String] The error message.
    def self.error_msg_abort(b_msg)
      puts '[ERROR] '+ B_ANSI_WHITE_ON_RED_BGCOLOR + b_msg + B_ANSI_RESET_COLOR
      HrzTagFunctions.context_array_push('hrz_msgs', 'error_abort', b_msg)
    end  # error_msg_abort


    # Retrieve messages, that were collected so far.
    # @param b_category      [Symbol, String]    Message category to be retrieved: 'debug', 'info', 'warning', 'error', 'error_abort'
    # @param b_previous_msgs [String]            Previous message(s), where you want the retrieved messages appended. Pass nil or '' for none.
    # @param b_delim         [String]            Delimiter string between messages
    # @param l_max           [Integer, optional] Maximum length of result string. nil means: no limit.
    # @return                [String]            Result string
    def self.retrieve_msgs(b_category, b_previous_msgs, b_delim, l_max=nil)
      arr_res = []
      arr_res << b_previous_msgs   unless b_previous_msgs.nil? || b_previous_msgs.empty?
      arr_coll = HrzTagFunctions.get_context_value('hrz_msgs', b_category, nil)
      arr_res += arr_coll          if arr_coll.is_a?(Array)
      b_ret = arr_res.join(b_delim)
      if l_max.nil?
        b_ret
      else
        b_ret[0..l_max]
      end
    end  # retrieve_msgs


    # Rails compatible interface
    def self.logger
      #defined?(Rails) ? Rails.logger : self
      self   # For now. Rails.logger has no debug_msg method, would have to switch back to debug/info/...
    end
  end  # class HrzLogger
  

  
  # Error class for HRZ tag errors
  class HrzError < StandardError
    attr_reader :context
    
    def initialize(message, context = {})
      super(message)
      @context = context
    end
  end  # class HrzError
  

  # -------------------------------------------------------------------------------------------------------------------------------


  # Parser for HRZ tags
  class HrzTagParser < Parslet::Parser
    # Whitespace inside of tags (ignored)
    rule(:space)  { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
    
    # Tag tokens
    rule(:tag_start)      { str('<HRZ')  >> space  }
    rule(:tag_start_cl)   { str('</HRZ') >> space  }
    rule(:tag_end_more)   { str('+>')    >> space? }
    rule(:tag_end_closed) { str('>')               }   # Retain whitespace outside of <HRZ tags.
    
    # HRZ tag function names
    rule(:func_get_param)        { str('get_param').as(:func) }   # Creates a hash {:func => "get_param"}
    rule(:func_tkt_old)          { str('tkt_old').as(:func) }
    rule(:func_tkt_new)          { str('tkt_new').as(:func) }
    rule(:func_set_param)        { str('set_param').as(:func) }
    rule(:func_tkt_show_info)    { str('show_info').as(:func) }
    rule(:func_tkt_show_warning) { str('show_warning').as(:func) }
    rule(:func_tkt_show_error)   { str('show_error').as(:func) }

    rule(:func_if)     { str('if')     >> space? }
    rule(:func_then)   { str('then')   >> space? }
    rule(:func_else)   { str('else')   >> space? }
    rule(:func_end_if) { str('end_if') >> space? }
    rule(:func_on_error) { str('on_error').as(:func) >> space? }

    rule(:hrz_function) { 
      (func_get_param | func_tkt_old | func_tkt_new | func_set_param | func_on_error) >> space?
    }
    
    # Any text without a tag_start:
    rule(:any_text_wo_tag_start) {
      (tag_start.absent? >> any).repeat(1).as(:text)
    }

    # A quoted string. (Copied from parslet/example/string_parser.rb)
    rule :quoted_string do
      str('"') >>
      (
        (str('\\') >> any) |
        (str('"').absent? >> any)
      ).repeat.as(:quoted) >>
      str('"')
    end

    # An identifier: [0-9A-Z_a-z]
    rule(:identifier) {
      match('\w').repeat(1).as(:identifier)
    }

    
    # Numbers (Integer and Float)
    rule(:num_const) {
      (str('-').maybe >> match('[0-9]').repeat(1) >>
       (str('.') >> match('[0-9]').repeat(1)).maybe).as(:num_const)
    }


    # 1 parameter inside a <HRZ> tag.
    rule(:hrz_tag_param1) {
      identifier.as(:param_nm_key) >> (str('=') | str(':')) >> quoted_string.as(:param_nm_val) |
      identifier.as(:param_nm_key) >> (str('=') | str(':')) >> num_const.as(:param_nm_val)     |
      identifier.as(:param_nm_key) >> (str('=') | str(':')) >> identifier.as(:param_nm_val)    |
      quoted_string.as(:param_unnam)                                                           |
      num_const.as(:param_unnam)                                                               |
      identifier.as(:param_unnam)
    }
    
    # 1 parameter outside of <HRZ> tags (between them, for long format)
    rule(:hrz_outs_param1) {
      identifier.as(:param_nm_key) >> (str('=') | str(':')) >> single_hrz_tag.as(:param_nm_val) |
      hrz_tag_param1                                                           |
      single_hrz_tag.as(:param_unnam)
    }

    # A list of parameters inside a <HRZ> tag, possibly empty.
    rule(:hrz_tag_param_list) {
      (hrz_tag_param1 >> space?).repeat.as(:params)
    }

    # A list of parameters outside of <HRZ> tags (between them, for long format), possibly empty.
    rule(:hrz_outs_param_list) {
      (hrz_outs_param1 >> space?).repeat.as(:params)
    }

    
    # Boolean Expression Parser
    # Constants
    rule(:bool_true) { (str('true') | str('TRUE')).as(:bool_const)    >> space? }
    rule(:bool_false) { (str('false') | str('FALSE')).as(:bool_const) >> space? }

    # Operators
    rule(:op_and) { (str('AND') | str('&&')).as(:op) >> space? }
    rule(:op_or)  { (str('OR') | str('||')).as(:op)  >> space? }
    rule(:op_not) { (str('NOT') | str('!')).as(:op)  >> space? }
    rule(:op_eq)  { str('==').as(:op) >> space? }
    rule(:op_le)  { str('<=').as(:op) >> space? }
    rule(:op_ge)  { str('>=').as(:op) >> space? }
    rule(:op_lt)  { str('<').as(:op)  >> space? }
    rule(:op_gt)  { str('>').as(:op)  >> space? }
    rule(:op_mul) { str('*').as(:op)  >> space? }
    rule(:op_div) { str('/').as(:op)  >> space? }
    rule(:op_add) { str('+').as(:op)  >> space? }
    rule(:op_sub) { str('-').as(:op)  >> space? }
    
    # Arithmetic Expressions with precedence
    rule(:arith_primary) {
      str('(') >> space? >> arith_expr >> str(')') >> space? |
      num_const.as(:num_const_arith) >> space? |
      single_hrz_tag.as(:tag_value) >> space?
    }
    
    rule(:arith_factor) {
      (arith_primary.as(:left) >> (op_mul | op_div) >> arith_factor.as(:right)).as(:binary_arith) |
      arith_primary
    }
    
    rule(:arith_expr) {
      (arith_factor.as(:left) >> (op_add | op_sub) >> arith_expr.as(:right)).as(:binary_arith) |
      arith_factor
    }
    
    # Comparison expressions
    rule(:comparison) {
      (arith_expr.as(:left) >> (op_eq | op_le | op_ge | op_lt | op_gt) >> arith_expr.as(:right)).as(:comparison)
    }
    
    # Boolean primary expressions
    rule(:bool_primary) {
      str('(') >> space? >> bool_expr >> str(')') >> space? |
      comparison |
      bool_true |
      bool_false # |
      #single_hrz_tag.as(:tag_bool)
    }
    
    # NOT has highest precedence
    rule(:bool_not) {
      (op_not >> bool_primary.as(:expr)).as(:not_expr) |
      bool_primary
    }
    
    # AND has medium precedence
    rule(:bool_and) {
      (bool_not.as(:left) >> op_and >> bool_and.as(:right)).as(:binary_bool) |
      bool_not
    }
    
    # OR has lowest precedence
    rule(:bool_expr) {
      (bool_and.as(:left) >> op_or >> bool_expr.as(:right)).as(:binary_bool) |
      bool_and
    }
    
    # Single HRZ Tag
    rule(:single_hrz_tag) {
      result = (
        # Type 1, short: <HRZ func params>
        (tag_start >> hrz_function >>                hrz_tag_param_list >>              tag_end_closed).as(:hrz_tag_short) |

        # Type 2, longer: <HRZ func params1 +> params2 </HRZ func >
        (tag_start >> hrz_function.as(:func_open) >> hrz_tag_param_list.as(:params1) >> tag_end_more >>
         hrz_outs_param_list.as(:params2) >> tag_start_cl >> hrz_function.as(:func_close) >> tag_end_closed).as(:hrz_tag_long) |

        # IF-THEN-ELSE
        (tag_start >> func_if     >> tag_end_closed >> bool_expr.as(:condition)      >> space? >>
         tag_start >> func_then   >> tag_end_closed >> hrz_tag_text.as(:then_branch) >> space? >>
         tag_start >> func_else   >> tag_end_closed >> hrz_tag_text.as(:else_branch) >> space? >>
         tag_start >> func_end_if >> tag_end_closed).as(:if_else_tag) |

        # IF-THEN (without ELSE)
        (tag_start >> func_if     >> tag_end_closed >> bool_expr.as(:condition)      >> space? >>
         tag_start >> func_then   >> tag_end_closed >> hrz_tag_text.as(:then_branch) >> space? >>
         tag_start >> func_end_if >> tag_end_closed).as(:if_then_tag) |

        # ON_ERROR <HRZ on_error replacement_text +> params2 </HRZ on_error >
        (tag_start >> func_on_error >> hrz_tag_param_list.as(:error_params) >> tag_end_more >>
            hrz_tag_text.as(:protected_content) >> space? >>
        tag_start_cl >> func_on_error >> tag_end_closed).as(:on_error_tag)
      ).as(:single_hrz_tag)
      #HrzLogger.debug_msg("Parsing single_hrz_tag")
      result
    }
    
    # Top level text elements
    rule(:hrz_tag_text1) {
      single_hrz_tag        |
      any_text_wo_tag_start
    }
    
    rule(:hrz_tag_text) {
      hrz_tag_text1.repeat
    }
    
    root(:hrz_tag_text)
  end  # HrzTagParser


  # -------------------------------------------------------------------------------------------------------------------------------


  # Transform: process the parse tree
  class HrzTagTransform < Parslet::Transform
    # Simple text node
    rule(text: simple(:t)) do
      HrzLogger.transform_beg 'text', t.to_s.inspect
      t.to_s
    end


    # Parameter: Returns either a hash { key: string, val: string} or a string.
    #rule(param: simple(:p)) { p }
    rule(param_nm_key: { identifier: simple(:b_key) }, param_nm_val: { quoted:         simple(:b_val) })   { { key: b_key.to_s, val: b_val.to_s } }
    rule(param_nm_key: { identifier: simple(:b_key) }, param_nm_val: { num_const:      simple(:x_val) })   { { key: b_key.to_s, val: x_val.to_s } }
    rule(param_nm_key: { identifier: simple(:b_key) }, param_nm_val: { identifier:     simple(:b_val) })   { { key: b_key.to_s, val: b_val.to_s } }
    rule(param_nm_key: { identifier: simple(:b_key) }, param_nm_val:                   simple(:b_val)  )   { { key: b_key.to_s, val: b_val.to_s } } # single_hrz_tag
    rule(param_unnam:  {                                               quoted:         simple(:b_val) })   {                         b_val.to_s   }
    rule(param_unnam:  {                                               num_const:      simple(:x_val) })   {                         x_val.to_s   }
    rule(param_unnam:  {                                               identifier:     simple(:b_val) })   {                         b_val.to_s   }
    rule(param_unnam:                                                                  simple(:b_val)  )   {                         b_val.to_s   } # single_hrz_tag

    # Boolean constants
    rule(bool_const: simple(:val)) do
      val.to_s.upcase == 'TRUE'
    end
    
    # Numbers in arithmetic
    rule(num_const_arith: { num_const: simple(:n) }) do
      n.to_s.include?('.') ? n.to_s.to_f : n.to_s.to_i
    end
    
    # Arithmetic binary operations
    rule(binary_arith: { left: simple(:l), op: simple(:o), right: simple(:r) }) do
      left_val = l.is_a?(Numeric) ? l : l.to_f
      right_val = r.is_a?(Numeric) ? r : r.to_f
      
      case o.to_s
      when '*' then left_val * right_val
      when '/' 
        if right_val.zero?
          raise HrzError.new("Division by zero", { operation: "#{left_val} / #{right_val}" })
        end
        left_val / right_val
      when '+' then left_val + right_val
      when '-' then left_val - right_val
      end
    end # rule binary_arith

    
    # Comparison operations
    rule(comparison: { left: simple(:l), op: simple(:o), right: simple(:r) }) do
      left_val = l.is_a?(Numeric) ? l : l.to_s.to_f
      right_val = r.is_a?(Numeric) ? r : r.to_s.to_f
      
      case o.to_s
      when '==' then left_val == right_val
      when '<'  then left_val <  right_val
      when '<=' then left_val <= right_val
      when '>'  then left_val >  right_val
      when '>=' then left_val >= right_val
      end
    end
    
    # Boolean binary operation
    rule(binary_bool: { left: simple(:l), op: simple(:o), right: simple(:r) }) do
      left_val = l.is_a?(TrueClass) || l.is_a?(FalseClass) ? l : (l.to_s.upcase == 'TRUE')
      right_val = r.is_a?(TrueClass) || r.is_a?(FalseClass) ? r : (r.to_s.upcase == 'TRUE')
      
      case o.to_s.upcase
      when 'AND', '&&' then left_val && right_val
      when 'OR',  '||' then left_val || right_val
      end
    end
    
    # NOT operation
    rule(not_expr: { op: simple(:o), expr: simple(:e) }) do
      expr_val = e.is_a?(TrueClass) || e.is_a?(FalseClass) ? e : (e.to_s.upcase == 'TRUE')
      !expr_val
    end
    
    # Tag value in expression
    rule(tag_value: simple(:t)) { t.to_s.to_f }
    rule(tag_bool: simple(:t)) { t.to_s.upcase == 'TRUE' }
    

    # IF-THEN-ELSE tag
    rule(if_else_tag: {
      condition: simple(:cond),
      then_branch: sequence(:then_content),
      else_branch: sequence(:else_content)
    }) do
      condition_result = cond.is_a?(TrueClass) || cond.is_a?(FalseClass) ? cond : (cond.to_s.upcase == 'TRUE')
      
      if condition_result
        then_content.map(&:to_s).join
      else
        else_content.map(&:to_s).join
      end
    end  # if_else_tag
    

    # IF-THEN tag (without ELSE)
    rule(if_then_tag: {
      condition: simple(:cond),
      then_branch: sequence(:then_content)
    }) do
      condition_result = cond.is_a?(TrueClass) || cond.is_a?(FalseClass) ? cond : (cond.to_s.upcase == 'TRUE')
      
      if condition_result
        then_content.map(&:to_s).join
      else
        ""
      end
    end  # rule if_then_tag

    
    # ON_ERROR tag
    rule(on_error_tag: {
      error_params: simple(:params),
      protected_content: sequence(:content)
    }) do
      begin
        content.map(&:to_s).join
      rescue HrzError => e
        # HRZ error. Use replacement text.
        params.to_s
      end
    end  # rule on_error_tag 1
    
    rule(on_error_tag: {
      error_params: sequence(:params),
      protected_content: sequence(:content)
    }) do
      begin
        content.map(&:to_s).join
      rescue HrzError => e
        # HRZ error. Use replacement text.
        params.first.to_s
      end
    end  # rule on_error_tag 2

    
    # Short HRZ tag type: <HRZ func params>
    rule(hrz_tag_short: { func:   simple(:func_name),
                          params: subtree(:arr_params) }) do
      HrzLogger.transform_beg 'hrz_tag_short', arr_params.inspect
      result = HrzTagFunctions.call_dispatcher(func_name.to_s, arr_params)
      HrzLogger.transform_res result
      result
    end  # rule hrz_tag_short

    
    # Long HRZ tag type: <HRZ func params1 +> params2 </HRZ func >
    rule(hrz_tag_long: { func_open:  { func:   simple(:func_open) },
                         params1:    { params: subtree(:p1) },
                         params2:    { params: subtree(:p2) },
                         func_close: { func:   simple(:func_close) } }) do
      # Verify, that the 2 function names are equal
      if func_open.to_s != func_close.to_s
        raise HrzError.new("Function name mismatch: #{func_open} != #{func_close}")
      end
      HrzTagFunctions.call_dispatcher(func_open.to_s, p1 + p2)
    end  # rule hrz_tag_long


    rule(single_hrz_tag: simple(:res))  { res.to_s }
    rule(single_hrz_tag: { hrz_tag_short: simple(:res)})  { res.to_s }



  end  # class HrzTagTransform


  # -------------------------------------------------------------------------------------------------------------------------------


  # Main class for string processing
  class TagStringHelper
    # Processes a text, that may contain HRZ tags
    # @param input_text [String] Input text, may contain HRZ tags
    # @param dry_run [Boolean, default false] If true, tag functions will not be perfomed. Only syntax check.
    # @return [String] Processed string
    # @raise [HrzError] In case of errors, that were not caught by a surrounding on_error tag.
    def self.str_hrz(input_text, dry_run: false)
      clear_errors
      set_dry_run_mode(dry_run)
      
      return "" if input_text.nil? || input_text.empty?
      
      begin
        parser    = HrzTagParser.new
        transform = HrzTagTransform.new
        
        # Parse
        if HrzLogger.debug_enabled?
          parse_tree = parser.parse_with_debug(input_text, reporter: Parslet::ErrorReporter::Deepest.new)
        else
          parse_tree = parser.parse(input_text, reporter: Parslet::ErrorReporter::Deepest.new)
        end
        # Transform
        result = transform.apply(parse_tree)
        
        # Combine results into a single string
        output = if result.is_a?(Array)
          result.map(&:to_s).join
        else
          result.to_s
        end
        
        output
        
      rescue Parslet::ParseFailed => e
        # Parse errors
        error_msg = "Parse error at position #{e.parse_failure_cause.pos}: #{e.parse_failure_cause.to_s}"
        add_error(error_msg)
        HrzLogger.logger.error_msg "HRZ Tag str_hrz: Parse tree: #{e.parse_failure_cause.ascii_tree}"
        raise HrzError.new(error_msg, { cause: e })
        
      rescue HrzError => e
        # Pass HRZ errors on
        add_error(e.message)
        raise
        
      rescue StandardError => e
        # Other error
        error_msg = "Error processing HRZ tags: #{e.message}"
        add_error(error_msg)
        HrzLogger.logger.error_msg "HRZ Tag Error: #{e.message}\n#{e.backtrace.join("\n")}"
        raise HrzError.new(error_msg, { cause: e })
      ensure
        set_dry_run_mode(false)
      end
    end  # str_hrz
    

    
    # Performs a syntax check
    # @param input_text [String] Text to be tested.
    # @return [Hash] { valid: Boolean, errors: Array<String> }
    def self.validate_syntax(input_text)
      begin
        str_hrz(input_text, dry_run: true)
        { valid: !has_errors?, errors: errors }
      rescue HrzError => e
        { valid: false, errors: errors + [e.message] }
      end
    end  # validate_syntax
    

    
    # Evaluate boolean expression
    # @param condition_text [String]  boolean expression as text
    # @param dry_run [Boolean, default false] If true, tag functions will not be perfomed. Only syntax check.
    # @return [Boolean] Result
    # @raise [HrzError] In case of errors
    def self.evaluate_hrz_condition(condition_text, dry_run: false)
      return false if condition_text.nil? || condition_text.strip.empty?
      
      set_dry_run_mode(dry_run)
      
      begin
        # Step 1: Replace all <HRZ> tags by their values.
        processed_text = condition_text.dup
        
        # Find all <HRZ...> tags and replace them.
        loop do
          # Search for nach <HRZ...> bis zum schließenden />
          match = processed_text.match(/<HRZ\s+[^>]*\/>/)
          break unless match
          
          # Parse und evaluiere diesen Tag
          begin
            tag_result = str_hrz(match[0], dry_run: dry_run)
            processed_text.sub!(match[0], tag_result)
          rescue => e
            raise HrzError.new("Error evaluating tag in condition: #{e.message}", 
                              { tag: match[0], condition: condition_text })
          end
        end
        
        # Schritt 2: Boolean-Ausdruck parsen und evaluieren
        parser = HrzTagParser.new
        transform = HrzTagTransform.new
        
        # Parsen (nur bool_expr)
        parse_tree = parser.bool_expr.parse(processed_text)
        
        # Transformieren
        result = transform.apply(parse_tree)
        
        # In Boolean konvertieren
        if result.is_a?(TrueClass) || result.is_a?(FalseClass)
          result
        else
          result.to_s.upcase == 'TRUE'
        end
        
      rescue Parslet::ParseFailed => e
        error_msg = "Invalid condition: #{condition_text}"
        HrzLogger.logger.error_msg "HRZ Condition Parse Error: #{e.parse_failure_cause.ascii_tree}"
        raise HrzError.new(error_msg, { condition: condition_text, cause: e })
        
      rescue StandardError => e
        error_msg = "Error evaluating condition: #{e.message}"
        HrzLogger.logger.error_msg "HRZ Condition Error: #{e.message}"
        raise HrzError.new(error_msg, { condition: condition_text, cause: e })
      ensure
        set_dry_run_mode(false)
      end
    end  # evaluate_hrz_condition
    

    
    # Returns all errors, that occurred during processing, in an array of strings.
    # @return [Array<String>] List of error messages
    def self.errors
      Thread.current[:hrz_errors] || []
    end  # errors
    

    
    # Test, if there were errors
    # @return [Boolean] true, if there were errors
    def self.has_errors?
      !errors.empty?
    end  # has_errors?
    


    # Returns all errors, that occurred during processing, in a multiline text.
    # @return [String] Errors: multiline text.
    def self.errors_text
      errors.join("\n")
    end  # errors_text
    

    
    # Reports a HRZ error. (Will be called by HRZ tag functions)
    # @param message [String] Error message
    # @param context [Hash] Context (optional)
    def self.report_error(message, context = {})
      add_error(message)
      HrzLogger.error_msg "Problem in HRZ Function #{message} | Context: #{context.inspect}"
    end  # report_error
    


    # Are we in dry run mode?
    # @return [Boolean]
    def self.dry_run_mode?
      Thread.current[:hrz_dry_run] == true
    end  # dry_run_mode?
    

    
    private
    
    # Sets dry-run mode
    def self.set_dry_run_mode(enabled)
      Thread.current[:hrz_dry_run] = enabled
    end  # set_dry_run_mode
    


    # Appends an error to the list
    def self.add_error(message)
      Thread.current[:hrz_errors] ||= []
      Thread.current[:hrz_errors] << message
    end   # add_error
    


    # Clears the error list.
    def self.clear_errors
      Thread.current[:hrz_errors] = []
    end  # clear_errors

  end  # class TagStringHelper
end  # module HrzLib
