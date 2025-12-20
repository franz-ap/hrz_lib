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
#-------------------------------------------------------------------------------------------#
# Test-Datei für HRZ Tag Parser
# Diese Datei zeigt Beispiele für die Verwendung des HRZ Tag Systems
#-------------------------------------------------------------------------------------------#

require_relative 'tag_string_helper'

# Beispiele aus der Grammatik-Datei testen
def run_tests
  puts "=" * 80
  puts "HRZ Tag Parser Tests"
  puts "=" * 80
  
  # ============================================================================
  # BASIC TESTS: get_param und set_param
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "BASIC TESTS: get_param und set_param"
  puts "=" * 80
  
  # Kontext initialisieren
  HrzLib::HrzTagFunctions.initialize_context({
    price: "1234",
    customer: "Acme Corp",
    discount: "10"
  })
  
  # Test 1: Einfacher get_param ohne Defaultwert
  test_case(
    "Test 1: get_param ohne Default",
    'abc<HRZ get_param price />def',
    'abc1234def'
  )
  
  # Test 2: get_param mit Defaultwert
  test_case(
    "Test 2: get_param mit Default",
    'abc<HRZ get_param price, 0.0 />def',
    'abc1234def'
  )
  
  # Test 3: get_param mit langer Syntax
  test_case(
    "Test 3: get_param lange Syntax",
    'abc<HRZ get_param>price</HRZ get_param>def',
    'abc1234def'
  )
  
  # Test 4: get_param mit unbekanntem Parameter
  test_case(
    "Test 4: get_param unbekannt mit Default",
    'abc<HRZ get_param unknown, 999 />def',
    'abc999def'
  )
  
  # Test 5: Mehrere Tags
  test_case(
    "Test 5: Mehrere Tags",
    'Customer: <HRZ get_param customer />, Price: <HRZ get_param price />',
    'Customer: Acme Corp, Price: 1234'
  )
  
  # Test 6: set_param und dann get_param
  puts "\n" + "-" * 80
  puts "Test 6: set_param und get_param kombiniert"
  HrzLib::HrzTagFunctions.clear_context
  input = '<HRZ set_param total, 5000 />Total: <HRZ get_param total />'
  result = HrzLib::TagStringHelper.str_hrz(input)
  expected = 'Total: 5000'
  puts "Input:    #{input}"
  puts "Output:   #{result}"
  puts "Expected: #{expected}"
  puts result == expected ? "✓ PASS" : "✗ FAIL"
  
  # ============================================================================
  # BOOLEAN EXPRESSION TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "BOOLEAN EXPRESSION TESTS"
  puts "=" * 80
  
  # Test 7: evaluate_condition mit einfachen Konstanten
  test_condition("Test 7: Boolean true", "true", true)
  test_condition("Test 8: Boolean false", "false", false)
  test_condition("Test 9: Boolean TRUE", "TRUE", true)
  test_condition("Test 10: Boolean FALSE", "FALSE", false)
  
  # Test 11-16: Vergleiche
  test_condition("Test 11: 5 == 5", "5 == 5", true)
  test_condition("Test 12: 5 == 3", "5 == 3", false)
  test_condition("Test 13: 3 < 5", "3 < 5", true)
  test_condition("Test 14: 5 > 3", "5 > 3", true)
  test_condition("Test 15: 5 <= 5", "5 <= 5", true)
  test_condition("Test 16: 3 >= 5", "3 >= 5", false)
  
  # Test 17-19: Arithmetik in Vergleichen
  test_condition("Test 17: 2 * 3 == 6", "2 * 3 == 6", true)
  test_condition("Test 18: 10 / 2 == 5", "10 / 2 == 5", true)
  test_condition("Test 19: 2 + 3 > 4", "2 + 3 > 4", true)
  
  # Test 20-22: Boolean Operatoren
  test_condition("Test 20: true AND true", "true AND true", true)
  test_condition("Test 21: true AND false", "true AND false", false)
  test_condition("Test 22: true OR false", "true OR false", true)
  test_condition("Test 23: NOT true", "NOT true", false)
  test_condition("Test 24: NOT false", "NOT false", true)
  
  # Test 25-26: Komplexe Ausdrücke
  test_condition("Test 25: (3 < 5) AND (2 > 1)", "(3 < 5) AND (2 > 1)", true)
  test_condition("Test 26: (3 > 5) OR (2 < 4)", "(3 > 5) OR (2 < 4)", true)
  
  # ============================================================================
  # IF-THEN-ELSE TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "IF-THEN-ELSE TESTS"
  puts "=" * 80
  
  HrzLib::HrzTagFunctions.clear_context
  
  # Test 27: IF-THEN mit true
  test_case(
    "Test 27: IF-THEN mit true",
    '<HRZ if />true<HRZ then />YES<HRZ end_if />',
    'YES'
  )
  
  # Test 28: IF-THEN mit false
  test_case(
    "Test 28: IF-THEN mit false",
    '<HRZ if />false<HRZ then />YES<HRZ end_if />',
    ''
  )
  
  # Test 29: IF-THEN-ELSE mit true
  test_case(
    "Test 29: IF-THEN-ELSE mit true",
    '<HRZ if />true<HRZ then />YES<HRZ else />NO<HRZ end_if />',
    'YES'
  )
  
  # Test 30: IF-THEN-ELSE mit false
  test_case(
    "Test 30: IF-THEN-ELSE mit false",
    '<HRZ if />false<HRZ then />YES<HRZ else />NO<HRZ end_if />',
    'NO'
  )
  
  # Test 31: IF mit Vergleich
  HrzLib::HrzTagFunctions.initialize_context({ qty: "10" })
  test_case(
    "Test 31: IF mit Vergleich und get_param",
    'Qty: <HRZ if /><HRZ get_param qty /> > 5<HRZ then />HIGH<HRZ else />LOW<HRZ end_if />',
    'Qty: HIGH'
  )
  
  # Test 32: IF mit komplexer Bedingung
  test_case(
    "Test 32: IF mit AND",
    '<HRZ if />(3 < 5) AND (2 > 1)<HRZ then />Both true<HRZ else />Not both<HRZ end_if />',
    'Both true'
  )
  
  # ============================================================================
  # ERROR HANDLING TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "ERROR HANDLING TESTS"
  puts "=" * 80
  
  # Test 33: Division durch 0 mit on_error
  test_case(
    "Test 33: Division durch 0 mit on_error",
    'Result: <HRZ on_error ERROR +>Value: <HRZ if />10 / 0 > 5<HRZ then />OK<HRZ end_if /></HRZ on_error>',
    'Result: ERROR'
  )
  
  # Test 34: Division durch 0 OHNE on_error - sollte Fehler werfen
  puts "\n" + "-" * 80
  puts "Test 34: Division durch 0 OHNE on_error (erwartet Fehler)"
  HrzLib::HrzTagFunctions.clear_context
  begin
    input = 'Result: <HRZ if />10 / 0 > 5<HRZ then />OK<HRZ end_if />'
    result = HrzLib::TagStringHelper.str_hrz(input)
    puts "Input:  #{input}"
    puts "Output: #{result}"
    puts "✗ FAIL - sollte Fehler werfen"
  rescue HrzLib::HrzError => e
    puts "Input:  Result: <HRZ if />10 / 0 > 5<HRZ then />OK<HRZ end_if />"
    puts "✓ PASS - Fehler korrekt gefangen: #{e.message}"
    puts "Errors: #{HrzLib::TagStringHelper.errors_text}" if HrzLib::TagStringHelper.has_errors?
  end
  
  # Test 35: on_error mit normalem Inhalt (kein Fehler)
  test_case(
    "Test 35: on_error ohne Fehler",
    'Result: <HRZ on_error ERROR +>Value: <HRZ if />5 > 3<HRZ then />OK<HRZ end_if /></HRZ on_error>',
    'Result: Value: OK'
  )
  
  # Test 36: Fehlerprüfung nach str_hrz
  puts "\n" + "-" * 80
  puts "Test 36: Fehlerprüfung nach str_hrz"
  HrzLib::HrzTagFunctions.clear_context
  begin
    input = 'Valid text'
    result = HrzLib::TagStringHelper.str_hrz(input)
    puts "Input:      #{input}"
    puts "Output:     #{result}"
    puts "Has Errors: #{HrzLib::TagStringHelper.has_errors?}"
    puts HrzLib::TagStringHelper.has_errors? ? "✗ FAIL" : "✓ PASS"
  rescue HrzLib::HrzError => e
    puts "✗ FAIL - Unerwarteter Fehler: #{e.message}"
  end
  
  # ============================================================================
  # WHITESPACE TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "WHITESPACE TESTS"
  puts "=" * 80
  
  HrzLib::HrzTagFunctions.initialize_context({ price: "99" })
  
  # Test 37: Whitespace außerhalb Tags bleibt erhalten
  test_case(
    "Test 37: Whitespace außerhalb Tags",
    'Hello   World  <HRZ get_param price />  End',
    'Hello   World  99  End'
  )
  
  # Test 38: Whitespace innerhalb Tags wird ignoriert
  test_case(
    "Test 38: Whitespace innerhalb Tags",
    'X<HRZ    get_param    price    />Y',
    'X99Y'
  )
  
  # ============================================================================
  # DRY RUN TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "DRY RUN / SYNTAX VALIDATION TESTS"
  puts "=" * 80
  
  # Test 39: Dry-Run mit gültiger Syntax
  puts "\n" + "-" * 80
  puts "Test 39: Dry-Run mit gültiger Syntax"
  HrzLib::HrzTagFunctions.initialize_context({ price: "99" })
  begin
    input = 'Price: <HRZ get_param price /> EUR'
    result = HrzLib::TagStringHelper.str_hrz(input, dry_run: true)
    puts "Input:    #{input}"
    puts "Output:   #{result} (dry-run, Funktionen nicht ausgeführt)"
    puts "Expected: Price: 1 EUR (Dummy-Wert)"
    puts result == 'Price: 1 EUR' ? "✓ PASS" : "✗ FAIL"
  rescue HrzLib::HrzError => e
    puts "✗ FAIL - Exception: #{e.message}"
  end
  
  # Test 40: Dry-Run mit ungültiger Syntax
  puts "\n" + "-" * 80
  puts "Test 40: Dry-Run mit ungültiger Syntax"
  begin
    input = 'Price: <HRZ invalid_func price />'
    result = HrzLib::TagStringHelper.str_hrz(input, dry_run: true)
    puts "Input:  #{input}"
    puts "Output: #{result}"
    puts "✗ FAIL - sollte Fehler werfen"
  rescue HrzLib::HrzError => e
    puts "Input:  #{input}"
    puts "✓ PASS - Fehler korrekt erkannt: #{e.message}"
  end
  
  # Test 41: validate_syntax mit gültiger Syntax
  puts "\n" + "-" * 80
  puts "Test 41: validate_syntax mit gültiger Syntax"
  input = '<HRZ if />5 > 3<HRZ then />OK<HRZ end_if />'
  validation = HrzLib::TagStringHelper.validate_syntax(input)
  puts "Input:  #{input}"
  puts "Valid:  #{validation[:valid]}"
  puts "Errors: #{validation[:errors].inspect}"
  puts validation[:valid] ? "✓ PASS" : "✗ FAIL"
  
  # Test 42: validate_syntax mit ungültiger Syntax
  puts "\n" + "-" * 80
  puts "Test 42: validate_syntax mit ungültiger Syntax"
  input = '<HRZ if />5 >'
  validation = HrzLib::TagStringHelper.validate_syntax(input)
  puts "Input:  #{input}"
  puts "Valid:  #{validation[:valid]}"
  puts "Errors: #{validation[:errors].inspect}"
  puts !validation[:valid] ? "✓ PASS" : "✗ FAIL"
  
  # ============================================================================
  # TAG EVALUATION IN CONDITIONS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "TAG EVALUATION IN CONDITIONS"
  puts "=" * 80
  
  # Test 43: HRZ-Tag in Condition
  HrzLib::HrzTagFunctions.initialize_context({ threshold: "10" })
  test_case(
    "Test 43: HRZ-Tag in IF-Bedingung",
    '<HRZ if /><HRZ get_param threshold /> > 5<HRZ then />Above threshold<HRZ else />Below<HRZ end_if />',
    'Above threshold'
  )
  
  # Test 44: Mehrere HRZ-Tags in Condition
  HrzLib::HrzTagFunctions.initialize_context({ val1: "3", val2: "7" })
  test_case(
    "Test 44: Mehrere HRZ-Tags in Bedingung",
    '<HRZ if /><HRZ get_param val1 /> + <HRZ get_param val2 /> == 10<HRZ then />Sum is 10<HRZ else />Other sum<HRZ end_if />',
    'Sum is 10'
  )
  
  # Test 45: evaluate_condition mit HRZ-Tag
  puts "\n" + "-" * 80
  puts "Test 45: evaluate_condition mit HRZ-Tag"
  HrzLib::HrzTagFunctions.initialize_context({ price: "100" })
  begin
    condition = '<HRZ get_param price /> >= 50'
    result = HrzLib::TagStringHelper.evaluate_condition(condition)
    puts "Condition: #{condition}"
    puts "Result:    #{result}"
    puts "Expected:  true"
    puts result == true ? "✓ PASS" : "✗ FAIL"
  rescue HrzLib::HrzError => e
    puts "✗ FAIL - Exception: #{e.message}"
  end
  
  # ============================================================================
  # ERROR REPORTING FROM FUNCTIONS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "ERROR REPORTING FROM FUNCTIONS"
  puts "=" * 80
  
  # Test 46: Fehler in Funktion wird gemeldet
  puts "\n" + "-" * 80
  puts "Test 46: Fehler in get_param (fehlender Parameter-Name)"
  HrzLib::HrzTagFunctions.clear_context
  begin
    input = 'Value: <HRZ get_param />'
    result = HrzLib::TagStringHelper.str_hrz(input)
    puts "Input:  #{input}"
    puts "Output: #{result}"
    puts "✗ FAIL - sollte Fehler werfen"
  rescue HrzLib::HrzError => e
    puts "Input:  #{input}"
    puts "✓ PASS - Fehler korrekt gemeldet: #{e.message}"
    puts "Errors: #{HrzLib::TagStringHelper.errors_text}" if HrzLib::TagStringHelper.has_errors?
  end
  
  puts "\n" + "=" * 80
  puts "Tests abgeschlossen"
  puts "=" * 80
  
  # Kontext bereinigen
  HrzLib::HrzTagFunctions.clear_context
end

def test_case(title, input, expected)
  puts "\n" + "-" * 80
  puts title
  begin
    result = HrzLib::TagStringHelper.str_hrz(input)
    puts "Input:    #{input}"
    puts "Output:   #{result}"
    puts "Expected: #{expected}"
    success = result == expected
    puts success ? "✓ PASS" : "✗ FAIL"
    if HrzLib::TagStringHelper.has_errors?
      puts "Errors:   #{HrzLib::TagStringHelper.errors_text}"
    end
  rescue HrzLib::HrzError => e
    puts "Input:    #{input}"
    puts "✗ FAIL - Exception: #{e.message}"
    puts "Errors:   #{HrzLib::TagStringHelper.errors_text}" if HrzLib::TagStringHelper.has_errors?
  end
end

def test_condition(title, condition, expected)
  puts "\n" + "-" * 80
  puts title
  begin
    result = HrzLib::TagStringHelper.evaluate_condition(condition)
    puts "Condition: #{condition}"
    puts "Result:    #{result}"
    puts "Expected:  #{expected}"
    puts result == expected ? "✓ PASS" : "✗ FAIL"
  rescue HrzLib::HrzError => e
    puts "Condition: #{condition}"
    puts "✗ FAIL - Exception: #{e.message}"
  end
end

# Tests ausführen, wenn Datei direkt aufgerufen wird
if __FILE__ == $0
  run_tests
end