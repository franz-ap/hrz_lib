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

require 'parslet'
require_relative 'hrz_tag_functions'

module HrzLib
  # Fehlerklasse für HRZ-spezifische Fehler
  class HrzError < StandardError
    attr_reader :context
    
    def initialize(message, context = {})
      super(message)
      @context = context
    end
  end
  
  # Parser für HRZ-Tags
  class HrzTagParser < Parslet::Parser
    # Whitespace innerhalb von Tags (wird ignoriert)
    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
    
    # Tag-Tokens
    rule(:tag_start) { str('<HRZ') >> space }
    rule(:tag_start_cl) { str('</HRZ') >> space }
    rule(:tag_end_more) { str('+>') }
    rule(:tag_end_closed) { str('>') }
    
    # Funktionsnamen
    rule(:func_get_param) { str('get_param').as(:func) }
    rule(:func_set_param) { str('set_param').as(:func) }
    rule(:func_if) { str('if').as(:func) }
    rule(:func_then) { str('then').as(:func) }
    rule(:func_else) { str('else').as(:func) }
    rule(:func_end_if) { str('end_if').as(:func) }
    rule(:func_on_error) { str('on_error').as(:func) }
    
    rule(:hrz_function) { 
      func_get_param | func_set_param | func_on_error
    }
    
    # OTHER_TEXT: Text ohne TAG_* und ohne Whitespace, mindestens 1 Zeichen
    rule(:other_text_word) { 
      match('[^<>\s]').repeat(1).as(:text) 
    }
    
    # OTextList: Eine nicht-leere Zeichenkette ohne TAG_* 
    # Wichtig: Whitespace zwischen Wörtern wird erhalten!
    rule(:otext_list) {
      (other_text_word >> (space >> other_text_word).repeat).as(:otext)
    }
    
    # Parameter
    rule(:hrz_param1) {
      # Quoted string
      (str('"') >> space? >> otext_list.maybe.as(:quoted) >> space? >> str('"')) |
      # Single HRZ tag
      single_hrz_tag |
      # Plain text word
      other_text_word
    }
    
    rule(:hrz_param_list) {
      hrz_param1.as(:param) >> 
      (space? >> str(',') >> space? >> hrz_param1.as(:param)).repeat
    }
    
    rule(:hrz_params_arr) {
      # Mit eckigen Klammern
      (str('[') >> space? >> hrz_param_list.maybe.as(:params) >> space? >> str(']')) |
      # Ohne eckige Klammern
      hrz_param_list.as(:params) |
      # Leer
      str('').as(:params)
    }
    
    # Boolean Expression Parser
    # Konstanten
    rule(:bool_true) { (str('true') | str('TRUE')).as(:bool_const) >> space? }
    rule(:bool_false) { (str('false') | str('FALSE')).as(:bool_const) >> space? }
    
    # Zahlen (Integer und Float)
    rule(:number) { 
      (str('-').maybe >> match('[0-9]').repeat(1) >> 
       (str('.') >> match('[0-9]').repeat(1)).maybe).as(:number) >> space?
    }
    
    # Operatoren
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
    
    # Arithmetische Ausdrücke mit Präzedenz
    rule(:arith_primary) {
      str('(') >> space? >> arith_expr >> str(')') >> space? |
      number |
      single_hrz_tag.as(:tag_value)
    }
    
    rule(:arith_factor) {
      (arith_primary.as(:left) >> (op_mul | op_div) >> arith_factor.as(:right)).as(:binary_arith) |
      arith_primary
    }
    
    rule(:arith_expr) {
      (arith_factor.as(:left) >> (op_add | op_sub) >> arith_expr.as(:right)).as(:binary_arith) |
      arith_factor
    }
    
    # Vergleichsausdrücke
    rule(:comparison) {
      (arith_expr.as(:left) >> (op_eq | op_le | op_ge | op_lt | op_gt) >> arith_expr.as(:right)).as(:comparison)
    }
    
    # Boolean Primärausdrücke
    rule(:bool_primary) {
      str('(') >> space? >> bool_expr >> str(')') >> space? |
      comparison |
      bool_true |
      bool_false |
      single_hrz_tag.as(:tag_bool)
    }
    
    # NOT hat höchste Präzedenz
    rule(:bool_not) {
      (op_not >> bool_primary.as(:expr)).as(:not_expr) |
      bool_primary
    }
    
    # AND hat mittlere Präzedenz
    rule(:bool_and) {
      (bool_not.as(:left) >> op_and >> bool_and.as(:right)).as(:binary_bool) |
      bool_not
    }
    
    # OR hat niedrigste Präzedenz
    rule(:bool_expr) {
      (bool_and.as(:left) >> op_or >> bool_expr.as(:right)).as(:binary_bool) |
      bool_and
    }
    
    # Single HRZ Tag (verschiedene Varianten)
    rule(:single_hrz_tag) {
      # IF-THEN-ELSE Struktur
      (tag_start >> 
       func_if >> 
       space? >> 
       tag_end_closed >> 
       space? >>
       bool_expr.as(:condition) >>
       space? >>
       tag_start >> 
       func_then >> 
       space? >> 
       tag_end_closed >> 
       space? >>
       hrz_tag_text.as(:then_branch) >>
       space? >>
       tag_start >> 
       func_else >> 
       space? >> 
       tag_end_closed >> 
       space? >>
       hrz_tag_text.as(:else_branch) >>
       space? >>
       tag_start >> 
       func_end_if >> 
       space? >> 
       tag_end_closed).as(:if_else_tag) |
      
      # IF-THEN Struktur (ohne ELSE)
      (tag_start >> 
       func_if >> 
       space? >> 
       tag_end_closed >> 
       space? >>
       bool_expr.as(:condition) >>
       space? >>
       tag_start >> 
       func_then >> 
       space? >> 
       tag_end_closed >> 
       space? >>
       hrz_tag_text.as(:then_branch) >>
       space? >>
       tag_start >> 
       func_end_if >> 
       space? >> 
       tag_end_closed).as(:if_then_tag) |
      
      # ON_ERROR Struktur
      (tag_start >> 
       func_on_error >> 
       space? >>
       hrz_params_arr.as(:error_params) >>
       space? >>
       tag_end_more >> 
       space? >>
       hrz_tag_text.as(:protected_content) >>
       space? >>
       tag_start_cl >> 
       func_on_error >> 
       space? >> 
       tag_end_closed).as(:on_error_tag) |
      
      # Variante 1: <HRZ func params />
      (tag_start >> 
       hrz_function >> 
       space? >> 
       hrz_params_arr >> 
       space? >> 
       tag_end_closed).as(:hrz_tag_short) |
      
      # Variante 2: <HRZ func params1 +> params2 </HRZ func />
      (tag_start >> 
       hrz_function.as(:func_open) >> 
       space? >> 
       hrz_params_arr.as(:params1) >> 
       space? >> 
       tag_end_more >> 
       space? >>
       hrz_params_arr.as(:params2) >>
       space? >>
       tag_start_cl >> 
       hrz_function.as(:func_close) >> 
       space? >> 
       tag_end_closed).as(:hrz_tag_long)
    }
    
    # Text-Elemente auf oberster Ebene
    rule(:hrz_tag_text1) {
      single_hrz_tag | otext_list
    }
    
    rule(:hrz_tag_text) {
      hrz_tag_text1.repeat(1)
    }
    
    root(:hrz_tag_text)
  end
  
  # Transform für die Verarbeitung des Parse-Trees
  class HrzTagTransform < Parslet::Transform
    # Einfacher Text-Knoten
    rule(text: simple(:t)) { t.to_s }
    
    # OTextList - behält Whitespace bei
    rule(otext: sequence(:parts)) do
      parts.map(&:to_s).join(' ')
    end
    
    rule(otext: simple(:text)) do
      text.to_s
    end
    
    # Quoted parameter
    rule(quoted: simple(:text)) { text.to_s }
    rule(quoted: { otext: simple(:text) }) { text.to_s }
    rule(quoted: { otext: sequence(:parts) }) do
      parts.map(&:to_s).join(' ')
    end
    
    # Parameter
    rule(param: simple(:p)) { p }
    rule(param: { text: simple(:t) }) { t.to_s }
    rule(param: { quoted: simple(:q) }) { q.to_s }
    
    # Parameter-Array aufbauen
    rule(params: simple(:p)) do
      p.to_s.empty? ? [] : [p.to_s]
    end
    
    rule(params: sequence(:p)) do
      p.map { |param| param.is_a?(Hash) ? param[:param] : param }.compact
    end
    
    # Boolean Konstanten
    rule(bool_const: simple(:val)) do
      val.to_s.upcase == 'TRUE'
    end
    
    # Zahlen
    rule(number: simple(:n)) do
      n.to_s.include?('.') ? n.to_s.to_f : n.to_s.to_i
    end
    
    # Arithmetische Binäroperationen
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
    
    # Vergleichsoperationen
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
    
    # Boolean Binäroperationen
    rule(binary_bool: { left: simple(:l), op: simple(:o), right: simple(:r) }) do
      left_val = l.is_a?(TrueClass) || l.is_a?(FalseClass) ? l : (l.to_s.upcase == 'TRUE')
      right_val = r.is_a?(TrueClass) || r.is_a?(FalseClass) ? r : (r.to_s.upcase == 'TRUE')
      
      case o.to_s.upcase
      when 'AND', '&&' then left_val && right_val
      when 'OR', '||' then left_val || right_val
      end
    end
    
    # NOT Operation
    rule(not_expr: { op: simple(:o), expr: simple(:e) }) do
      expr_val = e.is_a?(TrueClass) || e.is_a?(FalseClass) ? e : (e.to_s.upcase == 'TRUE')
      !expr_val
    end
    
    # Tag-Wert in Expression
    rule(tag_value: simple(:t)) { t.to_s.to_f }
    rule(tag_bool: simple(:t)) { t.to_s.upcase == 'TRUE' }
    
    # IF-THEN-ELSE Tag
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
    
    # IF-THEN Tag (ohne ELSE)
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
    
    # ON_ERROR Tag
    rule(on_error_tag: {
      error_params: simple(:params),
      protected_content: sequence(:content)
    }) do
      begin
        content.map(&:to_s).join
      rescue HrzError => e
        # HRZ-spezifische Fehler: Replacement-Text verwenden
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
        # HRZ-spezifische Fehler: Replacement-Text verwenden
        params.first.to_s
      end
    end
    
    # Kurze HRZ-Tag Variante: <HRZ func params />
    rule(hrz_tag_short: {
      func: simple(:func_name),
      params: simple(:params)
    }) do
      params_array = params.to_s.empty? ? [] : [params.to_s]
      HrzTagFunctions.call_function(func_name.to_s, params_array)
    end
    
    rule(hrz_tag_short: {
      func: simple(:func_name),
      params: sequence(:params)
    }) do
      params_array = params.map { |p| p.is_a?(String) ? p : p.to_s }
      HrzTagFunctions.call_function(func_name.to_s, params_array)
    end
    
    # Lange HRZ-Tag Variante: <HRZ func params1 +> params2 </HRZ func />
    rule(hrz_tag_long: {
      func_open: simple(:func_open),
      params1: simple(:p1),
      params2: simple(:p2),
      func_close: simple(:func_close)
    }) do
      # Prüfen ob Funktionsnamen übereinstimmen
      if func_open.to_s != func_close.to_s
        raise HrzError.new("Function name mismatch: #{func_open} != #{func_close}")
      end
      
      # Beide Parameter-Arrays kombinieren
      params_array = []
      params_array << p1.to_s unless p1.to_s.empty?
      params_array << p2.to_s unless p2.to_s.empty?
      
      HrzTagFunctions.call_function(func_open.to_s, params_array)
    end
    
    rule(hrz_tag_long: {
      func_open: simple(:func_open),
      params1: sequence(:p1),
      params2: sequence(:p2),
      func_close: simple(:func_close)
    }) do
      if func_open.to_s != func_close.to_s
        raise HrzError.new("Function name mismatch: #{func_open} != #{func_close}")
      end
      
      params_array = []
      params_array += p1.map { |p| p.is_a?(String) ? p : p.to_s }
      params_array += p2.map { |p| p.is_a?(String) ? p : p.to_s }
      
      HrzTagFunctions.call_function(func_open.to_s, params_array)
    end
  end
  
  # Hauptklasse für die String-Verarbeitung
  class TagStringHelper
    # Verarbeitet einen Text mit HRZ-Tags
    # @param input_text [String] Eingabetext mit HRZ-Tags
    # @param dry_run [Boolean] Wenn true, werden Funktionen nicht ausgeführt (nur Syntaxprüfung)
    # @return [String] Verarbeiteter Text
    # @raise [HrzError] Bei Fehlern, wenn kein on_error Tag vorhanden ist
    def self.str_hrz(input_text, dry_run: false)
      clear_errors
      set_dry_run_mode(dry_run)
      
      return "" if input_text.nil? || input_text.empty?
      
      begin
        parser = HrzTagParser.new
        transform = HrzTagTransform.new
        
        # Parsen
        parse_tree = parser.parse(input_text)
        
        # Transformieren
        result = transform.apply(parse_tree)
        
        # Ergebnis zusammenbauen
        output = if result.is_a?(Array)
          result.map(&:to_s).join
        else
          result.to_s
        end
        
        output
        
      rescue Parslet::ParseFailed => e
        # Bei Parse-Fehlern
        error_msg = "Parse error at position #{e.parse_failure_cause.pos}: #{e.parse_failure_cause.to_s}"
        add_error(error_msg)
        Rails.logger.error "HRZ Tag Parse Error: #{e.parse_failure_cause.ascii_tree}"
        raise HrzError.new(error_msg, { cause: e })
        
      rescue HrzError => e
        # HRZ-spezifische Fehler weitergeben
        add_error(e.message)
        raise
        
      rescue StandardError => e
        # Bei anderen Fehlern
        error_msg = "Error processing HRZ tags: #{e.message}"
        add_error(error_msg)
        Rails.logger.error "HRZ Tag Error: #{e.message}\n#{e.backtrace.join("\n")}"
        raise HrzError.new(error_msg, { cause: e })
      ensure
        set_dry_run_mode(false)
      end
    end
    
    # Führt eine Syntaxprüfung durch ohne die Funktionen auszuführen
    # @param input_text [String] Zu prüfender Text
    # @return [Hash] { valid: Boolean, errors: Array<String> }
    def self.validate_syntax(input_text)
      begin
        str_hrz(input_text, dry_run: true)
        { valid: !has_errors?, errors: errors }
      rescue HrzError => e
        { valid: false, errors: errors + [e.message] }
      end
    end
    
    # Evaluiert einen Boolean-Ausdruck
    # @param condition_text [String] Boolean-Ausdruck als Text
    # @param dry_run [Boolean] Wenn true, werden Funktionen nicht ausgeführt
    # @return [Boolean] Ergebnis der Auswertung
    # @raise [HrzError] Bei Fehlern in der Auswertung
    def self.evaluate_condition(condition_text, dry_run: false)
      return false if condition_text.nil? || condition_text.strip.empty?
      
      set_dry_run_mode(dry_run)
      
      begin
        # Schritt 1: Alle <HRZ> Tags im Ausdruck durch ihre Werte ersetzen
        processed_text = condition_text.dup
        
        # Finde alle <HRZ...> Tags und ersetze sie
        loop do
          # Suche nach <HRZ...> bis zum schließenden />
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
        Rails.logger.error "HRZ Condition Parse Error: #{e.parse_failure_cause.ascii_tree}"
        raise HrzError.new(error_msg, { condition: condition_text, cause: e })
        
      rescue StandardError => e
        error_msg = "Error evaluating condition: #{e.message}"
        Rails.logger.error "HRZ Condition Error: #{e.message}"
        raise HrzError.new(error_msg, { condition: condition_text, cause: e })
      ensure
        set_dry_run_mode(false)
      end
    end
    
    # Gibt alle während der Verarbeitung aufgetretenen Fehler zurück
    # @return [Array<String>] Liste der Fehlermeldungen
    def self.errors
      Thread.current[:hrz_errors] || []
    end
    
    # Prüft ob Fehler aufgetreten sind
    # @return [Boolean] true wenn Fehler vorhanden sind
    def self.has_errors?
      !errors.empty?
    end
    
    # Gibt alle Fehler als Text zurück
    # @return [String] Fehler als mehrzeiligen Text
    def self.errors_text
      errors.join("\n")
    end
    
    # Meldet einen Fehler (kann von HRZ-Funktionen aufgerufen werden)
    # @param message [String] Fehlermeldung
    # @param context [Hash] Zusätzlicher Kontext (optional)
    def self.report_error(message, context = {})
      add_error(message)
      Rails.logger.error "HRZ Function Error: #{message} | Context: #{context.inspect}"
    end
    
    # Prüft ob im Dry-Run-Modus
    # @return [Boolean]
    def self.dry_run_mode?
      Thread.current[:hrz_dry_run] == true
    end
    
    private
    
    # Setzt den Dry-Run-Modus
    def self.set_dry_run_mode(enabled)
      Thread.current[:hrz_dry_run] = enabled
    end
    
    # Fügt einen Fehler zur Fehlerliste hinzu
    def self.add_error(message)
      Thread.current[:hrz_errors] ||= []
      Thread.current[:hrz_errors] << message
    end
    
    # Löscht die Fehlerliste
    def self.clear_errors
      Thread.current[:hrz_errors] = []
    end
  end
end