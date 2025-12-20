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
# HRZ Tag System - Verwendungsbeispiele
#-------------------------------------------------------------------------------------------#

# ============================================================================
# 1. GRUNDLEGENDE VERWENDUNG
# ============================================================================

# Context initialisieren
HrzLib::HrzTagFunctions.initialize_context({
  user_name: "Max Mustermann",
  issue_id: "12345",
  price: "99.50"
})

# Text mit HRZ-Tags verarbeiten
input = 'Hallo <HRZ get_param user_name />, Issue #<HRZ get_param issue_id />'
result = HrzLib::TagStringHelper.str_hrz(input)
# => "Hallo Max Mustermann, Issue #12345"

# Context bereinigen
HrzLib::HrzTagFunctions.clear_context


# ============================================================================
# 2. FEHLERBEHANDLUNG
# ============================================================================

# Variante A: Mit on_error Tag (lokale Fehlerbehandlung)
input = 'Result: <HRZ on_error ERROR +><HRZ if />10 / 0 > 5<HRZ then />OK<HRZ end_if /></HRZ on_error>'
result = HrzLib::TagStringHelper.str_hrz(input)
# => "Result: ERROR"

# Variante B: Ohne on_error (Fehler wird weitergegeben)
begin
  input = '<HRZ if />10 / 0 > 5<HRZ then />OK<HRZ end_if />'
  result = HrzLib::TagStringHelper.str_hrz(input)
rescue HrzLib::HrzError => e
  puts "Fehler: #{e.message}"
  puts "Details: #{HrzLib::TagStringHelper.errors_text}"
end

# Variante C: Fehlerprüfung nach Verarbeitung
input = 'Valid text with <HRZ get_param value, default />'
result = HrzLib::TagStringHelper.str_hrz(input)

if HrzLib::TagStringHelper.has_errors?
  puts "Warnungen aufgetreten:"
  puts HrzLib::TagStringHelper.errors_text
else
  puts "Ergebnis: #{result}"
end


# ============================================================================
# 3. SYNTAXVALIDIERUNG (DRY RUN)
# ============================================================================

# Methode 1: str_hrz mit dry_run Parameter
input = 'Price: <HRZ get_param price /> EUR'
result = HrzLib::TagStringHelper.str_hrz(input, dry_run: true)
# => "Price: 1 EUR" (Funktionen werden nicht ausgeführt, liefern Dummy-Wert "1")

# Methode 2: validate_syntax
input = '<HRZ if />5 > 3<HRZ then />OK<HRZ end_if />'
validation = HrzLib::TagStringHelper.validate_syntax(input)

if validation[:valid]
  puts "Syntax ist gültig!"
else
  puts "Syntax-Fehler:"
  validation[:errors].each { |err| puts "  - #{err}" }
end


# ============================================================================
# 4. IF-THEN-ELSE STRUKTUREN
# ============================================================================

HrzLib::HrzTagFunctions.initialize_context({ quantity: "15", threshold: "10" })

# Einfaches IF-THEN (ohne ELSE)
input = '<HRZ if />5 > 3<HRZ then />Größer<HRZ end_if />'
result = HrzLib::TagStringHelper.str_hrz(input)
# => "Größer"

# IF-THEN-ELSE
input = '<HRZ if />5 < 3<HRZ then />Größer<HRZ else />Kleiner oder gleich<HRZ end_if />'
result = HrzLib::TagStringHelper.str_hrz(input)
# => "Kleiner oder gleich"

# IF mit get_param
input = '<HRZ if /><HRZ get_param quantity /> > <HRZ get_param threshold /><HRZ then />Over threshold<HRZ else />Under<HRZ end_if />'
result = HrzLib::TagStringHelper.str_hrz(input)
# => "Over threshold"

# Komplexe Bedingung mit AND/OR
input = '<HRZ if />(5 > 3) AND (2 < 4)<HRZ then />Both true<HRZ else />Not both<HRZ end_if />'
result = HrzLib::TagStringHelper.str_hrz(input)
# => "Both true"


# ============================================================================
# 5. BOOLEAN EXPRESSIONS
# ============================================================================

# evaluate_condition für standalone Boolean-Auswertung
result = HrzLib::TagStringHelper.evaluate_condition("5 > 3")
# => true

result = HrzLib::TagStringHelper.evaluate_condition("(3 < 5) AND (2 > 1)")
# => true

result = HrzLib::TagStringHelper.evaluate_condition("NOT (5 == 3)")
# => true

# Mit get_param in Condition
HrzLib::HrzTagFunctions.initialize_context({ price: "100" })
result = HrzLib::TagStringHelper.evaluate_condition("<HRZ get_param price /> >= 50")
# => true

# Arithmetische Ausdrücke
result = HrzLib::TagStringHelper.evaluate_condition("2 * 3 + 4 == 10")
# => true

result = HrzLib::TagStringHelper.evaluate_condition("(10 / 2) > 4")
# => true


# ============================================================================
# 6. FEHLER AUS FUNKTIONEN MELDEN
# ============================================================================

# In einer eigenen HRZ-Funktion:
def self.hrz_strfunc_custom_function(params)
  value = params[0]
  
  if value.nil? || value.empty?
    # Fehler melden
    HrzLib::TagStringHelper.report_error(
      "custom_function: value parameter is required",
      { function: 'custom_function', params: params }
    )
    raise HrzLib::HrzError.new("Missing value parameter")
  end
  
  # ... Verarbeitung ...
  
  return result
end


# ============================================================================
# 7. VERWENDUNG IN REDMINE CONTROLLER/HELPER
# ============================================================================

class MyController < ApplicationController
  def process_template
    template_text = params[:template]
    
    begin
      # Context aus Issue-Daten initialisieren
      HrzLib::HrzTagFunctions.initialize_context({
        issue_id: @issue.id,
        subject: @issue.subject,
        author: @issue.author.name,
        status: @issue.status.name,
        priority: @issue.priority.name,
        # Custom Fields
        price: @issue.custom_field_value(1),
        quantity: @issue.custom_field_value(2)
      })
      
      # Template verarbeiten
      result = HrzLib::TagStringHelper.str_hrz(template_text)
      
      # Warnungen prüfen
      if HrzLib::TagStringHelper.has_errors?
        flash[:warning] = "Warnungen: #{HrzLib::TagStringHelper.errors_text}"
      end
      
      render plain: result
      
    rescue HrzLib::HrzError => e
      # Schwerwiegender Fehler
      flash[:error] = "Fehler bei der Template-Verarbeitung: #{e.message}"
      render plain: template_text
      
    ensure
      # Immer Context bereinigen
      HrzLib::HrzTagFunctions.clear_context
    end
  end
  
  def validate_template
    template_text = params[:template]
    
    validation = HrzLib::TagStringHelper.validate_syntax(template_text)
    
    render json: {
      valid: validation[:valid],
      errors: validation[:errors]
    }
  end
end


# ============================================================================
# 8. BEISPIEL: EMAIL-TEMPLATE MIT HRZ-TAGS
# ============================================================================

email_template = <<~TEMPLATE
  Hallo <HRZ get_param user_name />,
  
  <HRZ if /><HRZ get_param priority /> == "Hoch"<HRZ then />
  DRINGEND: Ihre Aufgabe "<HRZ get_param subject />" erfordert sofortige Aufmerksamkeit!
  <HRZ else />
  Ihre Aufgabe "<HRZ get_param subject />" wartet auf Bearbeitung.
  <HRZ end_if />
  
  <HRZ on_error Preis nicht verfügbar +>
  Geschätzter Preis: <HRZ get_param price /> EUR
  </HRZ on_error>
  
  <HRZ set_param total_amount, <HRZ get_param price /> * <HRZ get_param quantity /> />
  Gesamtbetrag: <HRZ get_param total_amount /> EUR
  
  Mit freundlichen Grüßen,
  Ihr Redmine-System
TEMPLATE

HrzLib::HrzTagFunctions.initialize_context({
  user_name: "Max Mustermann",
  subject: "Kritischer Bug",
  priority: "Hoch",
  price: "50.00",
  quantity: "3"
})

email_text = HrzLib::TagStringHelper.str_hrz(email_template)
puts email_text

HrzLib::HrzTagFunctions.clear_context


# ============================================================================
# 9. CONTEXT-MANAGEMENT
# ============================================================================

# Context initialisieren mit Hash
HrzLib::HrzTagFunctions.initialize_context({
  key1: "value1",
  key2: "value2"
})

# Einzelnen Wert setzen
HrzLib::HrzTagFunctions.set_context_value(:key3, "value3")

# Einzelnen Wert abrufen
value = HrzLib::HrzTagFunctions.get_context_value(:key1, "default")
# => "value1"

# Gesamten Context abrufen
context = HrzLib::HrzTagFunctions.current_context
# => { key1: "value1", key2: "value2", key3: "value3" }

# Context bereinigen
HrzLib::HrzTagFunctions.clear_context


# ============================================================================
# 10. BEST PRACTICES
# ============================================================================

# ✓ IMMER Context nach Verwendung bereinigen
begin
  HrzLib::HrzTagFunctions.initialize_context(data)
  result = HrzLib::TagStringHelper.str_hrz(text)
ensure
  HrzLib::HrzTagFunctions.clear_context  # Auch bei Fehlern!
end

# ✓ Syntaxvalidierung VOR der eigentlichen Verarbeitung
validation = HrzLib::TagStringHelper.validate_syntax(user_input)
if validation[:valid]
  result = HrzLib::TagStringHelper.str_hrz(user_input)
else
  show_errors(validation[:errors])
end

# ✓ on_error für nicht-kritische Fehler verwenden
template = 'Price: <HRZ on_error N/A +><HRZ get_param optional_price /></HRZ on_error>'

# ✓ Fehlerprüfung nach Verarbeitung
result = HrzLib::TagStringHelper.str_hrz(text)
if HrzLib::TagStringHelper.has_errors?
  log_warnings(HrzLib::TagStringHelper.errors)
end

# ✓ In Funktionen report_error für nicht-fatale Probleme
def self.my_function(params)
  if params[0].empty?
    HrzLib::TagStringHelper.report_error("Warning: empty parameter")
    return "default"  # Trotzdem weiter
  end
  # ...
end