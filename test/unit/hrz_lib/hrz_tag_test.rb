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
# Test script for the HRZ tag parser.
# Usage examples.
#-------------------------------------------------------------------------------------------#
# For a standalone test with ruby:
# - Install parslet gem:
#     gem install parslet
# - cd into the plugins/hrz_lib directory
# - Run this test script, that you are viewing currently:
#   ruby test/unit/hrz_lib/hrz_tag_test.rb
# - Run this test script with debug info enabled:
#   HRZ_DEBUG=1 ruby test/unit/hrz_lib/hrz_tag_test.rb
# - Exit after first failure (2 options available):
#   ruby test/unit/hrz_lib/hrz_tag_test.rb --exit-on-fail
#   EXIT_ON_FAIL=1 ruby test/unit/hrz_lib/hrz_tag_test.rb
# - With debug info, stop after first failure:
#   HRZ_DEBUG=1 EXIT_ON_FAIL=1 ruby test/unit/hrz_lib/hrz_tag_test.rb
#-------------------------------------------------------------------------------------------#

require_relative '../../../lib/hrz_lib/hrz_tag_parser'

# Globale Variable für Fehler-Zähler
$test_failures = 0
$exit_on_first_failure = ENV['EXIT_ON_FAIL'] == '1' || ARGV.include?('--exit-on-fail')

# Examples from the grammar file:
def run_tests
  HrzLib::HrzLogger.debug_enable(ENV['HRZ_DEBUG'] == '1')
  puts "=" * 80
  puts "HRZ Tag Parser Tests"
  puts "=" * 80
  
  # ============================================================================
  # BASIC TESTS: get_param und set_param
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "BASIC TESTS: get_param und set_param"
  puts "=" * 80
  
  # Initialize the context
  HrzLib::HrzTagFunctions.initialize_context({
    price:    "1234",
    customer: "James Corp",
    discount: "10",
    qty:      "10",
    tkt_old:  { cf_id_291: '2.5' },
    tkt_new:  { cf_id_291: '3.3' },
  })

  test_case("Test 0: special dev/debug test", '<HRZ    get_param     tkt_old sub:cf_id_291 "nvlx999" "formatxto_f">', '2.5')

  # Test 1: Simple text and get_param without default value
  test_case("Test A.1: text",                                  'abc',                                          'abc')
  test_case("Test A.1a: text",                                 'ab<c>d',                                       'ab<c>d')
  test_case("Test A.1b: text",                                 'abc>d"ef"g',                                   'abc>d"ef"g')
  test_case("Test A.1c: get_param w/o default",                '<HRZ get_param "price" >',                     '1234')
  test_case("Test A.1d: get_param w/o default",                'abc<HRZ get_param "price">def',                'abc1234def')
  test_case("Test A.1e: get_param w/o default",                'abc<HRZ get_param price>def',                  'abc1234def')
  test_case("Test A.1f: get_param w/o default + blanks",       '  a  bc   <HRZ    get_param    price  >  def', '  a  bc   1234  def')
  test_case("Test A.1g: get_param w/o default, non-existing",  'abc<HRZ get_param xxx>def',                    'abcdef')

  # Test 2: get_param with default value
  test_case("Test A.2: get_param with default, exists",        'abc<HRZ get_param price  0.0  >def',           'abc1234def')
  test_case("Test A.2a: get_param with default, non-existing", 'abc<HRZ get_param xxx 0.0>def',                'abc0.0def')
  test_case("Test A.2b: get_param with def, non-ex, weird",    'abc<HRZ get_param 3.14 price  0.0   "]">def',  'abcprice 0.0 ]def')

  # Test 3: get_param, long syntax
  test_case("Test A.3: get_param, long syntax",                'abc<HRZ get_param +>price</HRZ get_param>def', 'abc1234def')

  # Miscellaneous
  test_case("Test A.4: Two tags", 'Customer: <HRZ get_param customer>, Price: <HRZ get_param price>', 'Customer: James Corp, Price: 1234')

  test_case("Test A.5: set_param and get_param combined", 'Old price: <HRZ get_param price>, <HRZ set_param price 1221>new: <HRZ get_param price>', 'Old price: 1234, new: 1221')

  test_case("Test A.6: get_param with more attributes",           '<HRZ get_param tkt_old sub:cf_id_291 "nvl=999" "conversion:to_f">', '2.5')
  test_case("Test A.7: tkt_old (get_param) with more attributes", '<HRZ tkt_old cf_id_291 nvl:999 conversion=to_f>', '2.5')

  # Nested <HRZ> tags
  test_case("Test A.8: nested <HRZ> tags", "<HRZ get_param nonex+>  nvl=<HRZ get_param discount>uvw </HRZ get_param> ghi",  "10 uvw ghi")

  #HrzLib::HrzTagFunctions.clear_context
  
  # ============================================================================
  # BOOLEAN EXPRESSION TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "BOOLEAN EXPRESSION TESTS"
  puts "=" * 80
  
  # Tests: evaluate_hrz_condition with simple constants
  test_condition("Test B.1: Boolean true", "true", true)
  test_condition("Test B.2: Boolean false", "false", false)
  test_condition("Test B.3: Boolean TRUE", "TRUE", true)
  test_condition("Test B.4: Boolean FALSE", "FALSE", false)
  
  # Tests: Comparing numbers
  test_condition("Test B.5: 5 == 5", "5 == 5", true)
  test_condition("Test B.6: 5 == 3", "5 == 3", false)
  test_condition("Test B.7: 3 < 5", "3 < 5", true)
  test_condition("Test B.8: 5 > 3", "5 > 3", true)
  test_condition("Test B.9: 5 <= 5", "5 <= 5", true)
  test_condition("Test B.10: 3 >= 5", "3 >= 5", false)
  
  # Tests: Arithmetic in comparisons
  test_condition("Test B.11: 2 * 3 == 6", "2 * 3 == 6", true)
  test_condition("Test B.12: 10 / 2 == 5", "10 / 2 == 5", true)
  test_condition("Test B.13: 2 + 3 > 4", "2 + 3 > 4", true)
  
  # Tests: Boolean operators
  test_condition("Test B.14: true AND true", "true AND true", true)
  test_condition("Test B.15: true AND false", "true AND false", false)
  test_condition("Test B.16: true OR false", "true OR false", true)
  test_condition("Test B.17: NOT true", "NOT true", false)
  test_condition("Test B.18: NOT false", "NOT false", true)
  
  # Tests: A little bit more complex expressions
  test_condition("Test B.19: (3 < 5) AND (2 > 1)", "(3 < 5) AND (2 > 1)", true)
  test_condition("Test B.20: (3 > 5) OR (2 < 4)", "(3 > 5) OR (2 < 4)", true)
  
  # Tests: with get_param
  test_condition("Test B.21: <HRZ get_param qty> > 5",                "<HRZ get_param qty> > 5", true)
  test_condition("Test B.22: <HRZ get_param qty> > 5 AND 2 * 3 == 6", "<HRZ get_param qty> > 5 AND 2 * 3 == 6", true)
  test_condition("Test B.23: 2* get_param, AND, comparison",     "<HRZ get_param qty> > 5 AND 2 * 3 == <HRZ get_param qty> - 4", true)
  test_condition("Test B.23a: 2* get_param, AND, comparison",     "<HRZ get_param qty> > 5 AND 2 * 3 == <HRZ get_param qty> - 2", false)
  test_condition("Test B.24: 2* get_param, to_f, comparison",    '<HRZ tkt_old cf_id_291 "nvl=999" "format=to_f"> < 3.1 AND <HRZ tkt_new cf_id_291 "nvl=0" "format=to_f"> >= 3.1', true)
  test_condition("Test B.24a: 2* get_param++, to_f, comparison", '<HRZ tkt_old cf_id_291 vfy="Impulse Phase" nvl=999 format=to_f> < 3.1 AND <HRZ tkt_new cf_id_291 nvl=0 format=to_f> >= 3.1', true)

  # Tests: string comparison
  test_case(     'Test B.30: string constant comparison, with tag',       '<HRZ if>"ABC" == "ABC"<HRZ then>good<HRZ else>wrong<HRZ end_if>', 'good')
  test_condition('Test B.30a: string constant comparison, condition',     '"ABC" == "ABC"', true)
  test_condition('Test B.31:  string constant comparison, condition',     '"ABC" == "XY"',  false)
  test_condition('Test B.32: string comparison, condition const==param',  '"ABC" == <HRZ get_param customer>',  false)
  test_case(     'Test B.32a: string comparison, with tag, const==param', '<HRZ if>"ABC" == <HRZ get_param customer><HRZ then>wrong<HRZ else>good<HRZ end_if>',  'good')
  test_condition('Test B.33: string comparison, condition const==param',  '"James Corp" == <HRZ get_param customer>',  true)
  test_case(     'Test B.33a: string comparison, with tag, const==param', '<HRZ if><HRZ get_param customer>=="James Corp"<HRZ then>good<HRZ else>wrong<HRZ end_if>',  'good')

  # Nested <HRZ> tags
  test_condition("Test B.40: nested <HRZ> tags", "<HRZ get_param nonex+>  nvl=<HRZ get_param discount>uvw </HRZ get_param> > 7", true)


  # ============================================================================
  # IF-THEN-ELSE TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "IF-THEN-ELSE TESTS"
  puts "=" * 80
  
  #HrzLib::HrzTagFunctions.clear_context
  
  test_case("Test 27: IF-THEN with true",       '<HRZ if>true<HRZ then>YES<HRZ end_if>',    'YES')
  test_case("Test 28: IF-THEN with false",      '<HRZ if>false<HRZ then>YES<HRZ end_if>',   ''   )
  test_case("Test 29: IF-THEN-ELSE with true",  '<HRZ if>true<HRZ then>YES<HRZ else>NO<HRZ end_if>',      'YES')
  test_case("Test 30: IF-THEN-ELSE with false", '<HRZ if >false<HRZ then >YES<HRZ else >NO<HRZ end_if >', 'NO' )
  test_case("Test 31: IF comparing get_param",  'Qty: <HRZ if><HRZ get_param qty> > 5<HRZ then>HIGH<HRZ else>LOW<HRZ end_if>', 'Qty: HIGH')
  test_case("Test 32: IF with AND",             '<HRZ if>(3 < 5) AND (2 > 1)<HRZ then>Both true<HRZ else>Not both<HRZ end_if>', 'Both true')
  
  # ============================================================================
  # ERROR HANDLING TESTS
  # ============================================================================
  
  puts "\n" + "=" * 80
  puts "ERROR HANDLING TESTS"
  puts "=" * 80
  
  # Test 33: Division durch 0 mit on_error
  test_case(
    "Test 33: Division durch 0 mit on_error",
    'Result: <HRZ on_error Problem detected. +>Value: <HRZ if>10 / 0 > 5<HRZ then>OK<HRZ end_if></HRZ on_error>',
    'Result: Problem detected.'
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
  
  # Test 45: evaluate_hrz_condition mit HRZ-Tag
  puts "\n" + "-" * 80
  puts "Test 45: evaluate_hrz_condition mit HRZ-Tag"
  HrzLib::HrzTagFunctions.initialize_context({ price: "100" })
  begin
    condition = '<HRZ get_param price /> >= 50'
    result = HrzLib::TagStringHelper.evaluate_hrz_condition(condition)
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



# Output the parse tree
def outp_parse_tree(b_input)
  begin
    parser = HrzLib::HrzTagParser.new
    parse_tree = parser.parse(b_input)
    puts "Parse Tree: " + parse_tree.inspect
  rescue => parse_error
    puts "\nCouldn't generate parse tree: #{parse_error.message}"
  end
end  # outp_parse_tree



# Output character positons
def outp_char_positions(b_prefix,  # Prefix text
                        n_pos)     # Number of character positions to be output.
   puts b_prefix + (0..(n_pos-1)).map { |i| ((i / 10) % 10) }.join   if n_pos > 10 # tens
   puts b_prefix + (0..(n_pos-1)).map { |i| ( i       % 10) }.join                 # ones
end  # outp_char_positions



# Perform one test
def test_case(title, input, expected)
  puts "\n" + "-" * 80
  puts title
  begin
    result = HrzLib::TagStringHelper.str_hrz(input)
    success = result == expected
    puts "Input:    #{input}"
    outp_char_positions("          ", input.length)   if ! success
    puts "Output:   #{result}"
    if success
      puts "✓ PASS"
      outp_parse_tree(input)   if ENV['HRZ_DEBUG']
    else
      puts "Expected: #{expected}"
      puts "✗ FAIL"
      outp_parse_tree(input)
      $test_failures += 1
      exit(1) if $exit_on_first_failure
    end
    if HrzLib::TagStringHelper.has_errors?
      puts "TagStringHelper errors:   #{HrzLib::TagStringHelper.errors_text}"
    end
  rescue HrzLib::HrzError => e
    puts "Input: #{input}"
    outp_char_positions("       ", input.length)
    puts "✗ FAIL - Exception: #{e.message}"
    puts "Error: #{HrzLib::TagStringHelper.errors_text}" if HrzLib::TagStringHelper.has_errors?
    $test_failures += 1
    exit(1) if $exit_on_first_failure
  end
end  # test_case



# Test one condition
def test_condition(title, condition, expected)
  puts "\n" + "-" * 80
  puts title
  begin
    result = HrzLib::TagStringHelper.evaluate_hrz_condition(condition)
    puts "Condition: #{condition}"
    puts "Result:    #{result}"
    puts "Expected:  #{expected}"
    success = result == expected
    if success
      puts "✓ PASS"
    else
      puts "✗ FAIL"
      $test_failures += 1
      exit(1) if $exit_on_first_failure
    end
  rescue HrzLib::HrzError => e
    puts "Condition: #{condition}"
    puts "✗ FAIL - Exception: #{e.message}"
    $test_failures += 1
    exit(1) if $exit_on_first_failure
  end
end  # test_condition



# Execute the tests, if the file was called directly.
if __FILE__ == $0
  run_tests
end
