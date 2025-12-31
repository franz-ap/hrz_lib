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

require 'parslet'    # https://kschiess.github.io/parslet/
require_relative 'hrz_tag_functions'

module HrzLib
  # Color codes for puts console output
  B_ANSI_RESET_COLOR           = "\e[0m"
  B_ANSI_YELLOW_BGCOLOR_STD    = "\e[43m"
  B_ANSI_YELLOW_BGCOLOR_BRIGHT = "\e[103m"
  B_ANSI_WHITE_ON_RED_BGCOLOR  = "\e[37;41m"

  # Logger wrapper, enabling standalone tests without Rails.
  class HrzLogger
    def self.debug_msg(b_msg)
      return unless ENV['HRZ_DEBUG'] == '1'
      puts '[DEBUG] ' + B_ANSI_YELLOW_BGCOLOR_STD + b_msg + B_ANSI_RESET_COLOR
      HrzTagFunctions.context_array_push('hrz_msgs', 'debug', b_msg)
    end

    def self.transform_beg(b_rule, b_msg)
      HrzLogger.debug_msg("Transform '#{b_rule}': #{b_msg}")
    end

    def self.transform_res(b_msg)
      HrzLogger.debug_msg("  ----->  #{b_msg}")
    end

    def self.info_msg(b_msg)
      puts "[INFO] #{b_msg}"
    end
    
    def self.warning_msg(b_msg)
      puts '[WARN] ' + B_ANSI_YELLOW_BGCOLOR_BRIGHT + b_msg + B_ANSI_RESET_COLOR
    end
    
    def self.error_msg(b_msg)
      puts '[ERROR] '+ B_ANSI_WHITE_ON_RED_BGCOLOR + b_msg + B_ANSI_RESET_COLOR
    end
    


    # Retrieve messages, that were collected so far.
    # @param b_category      [Symbol, String]    Message category to be retrieved: 'debug', 'info', 'warning', 'error'
    # @param b_previous_msgs [String]            Previous message(s), where you want the retrieved messages appended. Pass nil or '' for none.
    # @param b_delim         [String]            Delimiter string between messages
    # @param l_max           [Integer, optional] Maximum length of result string. nil means: no limit.
    # @return                [String]            Result string
    def self.retrieve_msgs(b_category, b_previous_msgs, b_delim, l_max=nil)
      puts "vorher #{b_previous_msgs}"
      arr = [ b_previous_msgs ]
      puts 'Mitte ' + arr.inspect
      arr += HrzTagFunctions.get_context_value('hrz_msgs', b_category, nil)
      puts 'Mitte2 ' + arr.inspect
      b_ret = arr.join(b_delim)
      puts 'fertig ' + b_ret.inspect
      if l_max.nil?
        b_ret
      else
        b_ret[0..l_max]
      end
    end  # retrieve_msgs



    # Rails compatible interface
    def self.logger
      defined?(Rails) ? Rails.logger : self
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
    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
    
    # Tag tokens
    rule(:tag_start) { str('<HRZ') >> space }
    rule(:tag_start_cl) { str('</HRZ') >> space }
    rule(:tag_end_more) { str('+>') }
    rule(:tag_end_closed) { space? >> str('>') }
    
    # HRZ tag function names
    rule(:func_get_param) { str('get_param').as(:func) }   # Creates a hash {:func => "get_param"}
    rule(:func_set_param) { str('set_param').as(:func) }
    rule(:func_if) { str('if') }
    rule(:func_then) { str('then') }
    rule(:func_else) { str('else') }
    rule(:func_end_if) { str('end_if') }
    rule(:func_on_error) { str('on_error').as(:func) }

    rule(:hrz_function) { 
      func_get_param | func_set_param | func_on_error
    }
    
    # Any text without a tag_start:
    rule(:any_text_wo_tag_start) {
      (tag_start.absent? >> any).repeat(1).as(:text)
    }

    # OTHER_TEXT: Text without TAG_* and without whitespace or comma, at least 1 character
    rule(:other_text_word) { 
      match('[^<>,\s]').repeat(1).as(:text)                                                |   # Without a '<' inside, it cannot contain a tag_start.
      match('\w').repeat >> str('<') >> match('[^H,\s]').repeat(1) >> match('\w').repeat      # If there is a '<' but it is not folloed by 'H': ---"---
    }
    # Same thing again, but comma allowed inside
    rule(:other_text_word_incl_comma) {
      match('[^<\s]').repeat(1).as(:text)  |
      match('\w').repeat >> str('<') >> match('[^H\s]').repeat(1) >> match('\w').repeat.as(:text)
    }

    
    # Numbers (Integer and Float)
    rule(:number) {
      (str('-').maybe >> match('[0-9]').repeat(1) >>
       (str('.') >> match('[0-9]').repeat(1)).maybe).as(:number)
    }

    # OTextList: A non-empty text string without any TAG_*
    # Whitespace between words will be retained.
    rule(:otext_list) {
      (other_text_word_incl_comma >> (space >> other_text_word_incl_comma).repeat).as(:otext)
    }
    
    # Parameter
    rule(:hrz_param1) {
      # Quoted string
      (str('"') >> space? >> otext_list.maybe.as(:quoted) >> space? >> str('"')) |
      # Number (before single_hrz_tag to avoid ambiguity)
      number |
      # Single HRZ tag
      single_hrz_tag |
      # Plain text word
      (tag_end_more | tag_end_closed).absent? >> other_text_word
    }
    
    rule(:hrz_param_list) {
      hrz_param1.as(:param) >> 
      (space? >> str(',') >> space? >> hrz_param1.as(:param)).repeat
    }
    
    rule(:hrz_params_arr) {
      # With square brackets
      (str('[') >> space? >> hrz_param_list.maybe.as(:params) >> space? >> str(']')) |
      # Without square brackets
      hrz_param_list.as(:params) |
      # Empty
      str('').as(:params)
    }
    
    # Boolean Expression Parser
    # Constants
    rule(:bool_true) { (str('true') | str('TRUE')).as(:bool_const) >> space? }
    rule(:bool_false) { (str('false') | str('FALSE')).as(:bool_const) >> space? }

    # Operators
    rule(:op_and) { (str('AND') | str('&&')).as(:op) >> space? }
    rule(:op_or) { (str('OR') | str('||')).as(:op) >> space? }
    rule(:op_not) { (str('NOT') | str('!')).as(:op) >> space? }
    rule(:op_eq) { str('==').as(:op) >> space? }
    rule(:op_le) { str('<=').as(:op) >> space? }
    rule(:op_ge) { str('>=').as(:op) >> space? }
    rule(:op_lt) { str('<').as(:op) >> space? }
    rule(:op_gt) { str('>').as(:op) >> space? }
    rule(:op_mul) { str('*').as(:op) >> space? }
    rule(:op_div) { str('/').as(:op) >> space? }
    rule(:op_add) { str('+').as(:op) >> space? }
    rule(:op_sub) { str('-').as(:op) >> space? }
    
    # Arithmetic Expressions with precedence
    rule(:arith_primary) {
      str('(') >> space? >> arith_expr >> str(')') >> space? |
      number >> space? |
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
        # Type 1: <HRZ func params />
        (tag_start >> hrz_function >>                space? >> hrz_params_arr >>              tag_end_closed).as(:hrz_tag_short) |

        # Type 2: <HRZ func params1 +> params2 </HRZ func >
        (tag_start >> hrz_function.as(:func_open) >> space? >> hrz_params_arr.as(:params1) >> tag_end_more >>
        space? >> hrz_params_arr.as(:params2) >> space? >> tag_start_cl >> hrz_function.as(:func_close) >> space? >> tag_end_closed).as(:hrz_tag_long) |

        # IF-THEN-ELSE
        (tag_start >> func_if     >> space? >> tag_end_closed >> space? >> bool_expr.as(:condition)      >> space? >>
        tag_start >> func_then   >> space? >> tag_end_closed >> space? >> hrz_tag_text.as(:then_branch) >> space? >>
        tag_start >> func_else   >> space? >> tag_end_closed >> space? >> hrz_tag_text.as(:else_branch) >> space? >>
        tag_start >> func_end_if >> space? >> tag_end_closed).as(:if_else_tag) |

        # IF-THEN (without ELSE)
        (tag_start >> func_if     >> space? >> tag_end_closed >> space? >> bool_expr.as(:condition)      >> space? >>
        tag_start >> func_then   >> space? >> tag_end_closed >> space? >> hrz_tag_text.as(:then_branch) >> space? >>
        tag_start >> func_end_if >> space? >> tag_end_closed).as(:if_then_tag) |

        # ON_ERROR <HRZ on_error replacement_text +> params2 </HRZ on_error >
        (tag_start    >> func_on_error >> space? >> hrz_params_arr.as(:error_params) >> space? >> tag_end_more >> space? >>
            hrz_tag_text.as(:protected_content) >> space? >>
        tag_start_cl >> func_on_error >> space? >> tag_end_closed).as(:on_error_tag)
      )
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

    # OTextList - retains whitespace
    rule(otext: sequence(:parts)) do
      parts.map(&:to_s).join(' ')
    end
    
    rule(otext: simple(:text)) do
      text.to_s
    end
    
    # Quoted parameter
    rule(quoted: simple(:text))            { HrzLogger.transform_beg 'qouted param/text',  text.to_s; text.to_s }
    rule(quoted: { otext: simple(:text) }) { HrzLogger.transform_beg 'qouted param/otext', text.to_s; text.to_s }
    rule(quoted: { otext: sequence(:parts) }) do
      result = parts.map(&:to_s).join(' ')
      HrzLogger.transform_beg 'qouted param/parts', result.inspect
      result
    end
    
    # Parameter
    rule(param: simple(:p)) { p }
    rule(param: { text: simple(:t) }) { t.to_s }
    rule(param: { quoted: simple(:q) }) { q.to_s }
    
    # Build parameter array
    rule(params: simple(:p)) do
      p.to_s.empty? ? [] : [p.to_s]
    end
    
    rule(params: sequence(:p)) do
      p.map { |param| param.is_a?(Hash) ? param[:param] : param }.compact
    end
    
    # Boolean constants
    rule(bool_const: simple(:val)) do
      val.to_s.upcase == 'TRUE'
    end
    
    # Zahlen
    rule(number: simple(:n)) do
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
    end
    
    # Comparison operations
    rule(comparison: { left: simple(:l), op: simple(:o), right: simple(:r) }) do
      left_val = l.is_a?(Numeric) ? l : l.to_s.to_f
      right_val = r.is_a?(Numeric) ? r : r.to_s.to_f
      
      case o.to_s
      when '==' then left_val == right_val
      when '<' then left_val < right_val
      when '<=' then left_val <= right_val
      when '>' then left_val > right_val
      when '>=' then left_val >= right_val
      end
    end
    
    # Boolean binary operation
    rule(binary_bool: { left: simple(:l), op: simple(:o), right: simple(:r) }) do
      left_val = l.is_a?(TrueClass) || l.is_a?(FalseClass) ? l : (l.to_s.upcase == 'TRUE')
      right_val = r.is_a?(TrueClass) || r.is_a?(FalseClass) ? r : (r.to_s.upcase == 'TRUE')
      
      case o.to_s.upcase
      when 'AND', '&&' then left_val && right_val
      when 'OR', '||' then left_val || right_val
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
    end
    
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
    end
    
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
    end
    
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
    end
    
    # Short HRZ tag type: <HRZ func params />
    rule(hrz_tag_short: {
      func: simple(:func_name),
      params: simple(:params)
    }) do
      params_array = params.to_s.empty? ? [] : [params.to_s]
      HrzTagFunctions.call_dispatcher(func_name.to_s, params_array)
    end
    
    rule(hrz_tag_short: {
      func: simple(:func_name),
      params: sequence(:params)
    }) do
      params_array = params.map { |p| p.is_a?(String) ? p : p.to_s }
      HrzTagFunctions.call_dispatcher(func_name.to_s, params_array)
    end
    
    # Long HRZ tag type: <HRZ func params1 +> params2 </HRZ func >
    rule(hrz_tag_long: {
      func_open: { func: simple(:func_open) },
      params1: subtree(:p1),
      params2: subtree(:p2),
      func_close: { func: simple(:func_close) }
    }) do
      # Verify, that the 2 function names are equal
      if func_open.to_s != func_close.to_s
        raise HrzError.new("Function name mismatch: #{func_open} != #{func_close}")
      end
      
      # Normalize both parameter subtrees to arrays and combine them into a single arry in the call:
      p1_array = [p1].flatten.reject { |x| x.to_s.empty? }.map(&:to_s)
      p2_array = [p2].flatten.reject { |x| x.to_s.empty? }.map(&:to_s)
      HrzTagFunctions.call_dispatcher(func_open.to_s, p1_array + p2_array)
    end  # rule hrz_tag_long

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
        parse_tree = parser.parse(input_text)
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
    def self.evaluate_condition(condition_text, dry_run: false)
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
    end  # evaluate_condition
    

    
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
      Rails.logger.error "HRZ Function Error: #{message} | Context: #{context.inspect}"
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
