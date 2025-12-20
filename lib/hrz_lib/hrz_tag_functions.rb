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
  # Container für alle HRZ-Tag-Funktionen
  class HrzTagFunctions
    # Zentrale Dispatcher-Methode
    # @param function_name [String] Name der aufzurufenden Funktion
    # @param params [Array<String>] Array mit String-Parametern
    # @return [String] Ergebnis der Funktion
    def self.call_function(function_name, params = [])
      # Im Dry-Run-Modus: Dummy-Wert zurückgeben ohne Funktion auszuführen
      if TagStringHelper.dry_run_mode?
        Rails.logger.debug "Dry-run: #{function_name}(#{params.inspect})"
        return "1"  # Standard-Dummy-Wert für Dry-Run
      end
      
      case function_name
      when 'get_param'
        hrz_strfunc_get_param(params)
      when 'set_param'
        hrz_strfunc_set_param(params)
      else
        Rails.logger.warn "Unknown HRZ function: #{function_name}"
        raise HrzError.new("Unknown function: #{function_name}", { function: function_name })
      end
    rescue HrzError
      # HrzError weitergeben
      raise
    rescue StandardError => e
      Rails.logger.error "Error in HRZ function #{function_name}: #{e.message}"
      raise HrzError.new("Error in function #{function_name}: #{e.message}", 
                        { function: function_name, params: params, cause: e })
    end
    
    # ============================================================================
    # Implementierung der einzelnen Funktionen
    # ============================================================================
    
    # get_param: Liest einen Parameter aus einem Kontext
    # Beispiele:
    #   <HRZ get_param price />           -> params: ["price"]
    #   <HRZ get_param price, 0.0 />      -> params: ["price", "0.0"]
    #   <HRZ get_param>price</HRZ get_param> -> params: ["price"]
    #
    # @param params [Array<String>] Parameter-Array
    #   params[0] = Parametername (erforderlich)
    #   params[1] = Defaultwert (optional)
    # @return [String] Wert des Parameters oder Defaultwert
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
        Rails.logger.debug "Parameter '#{param_name}' not found, using default: '#{default_value}'"
        default_value
      else
        value.to_s
      end
    end
    
    # set_param: Setzt einen Parameter im Kontext
    # Beispiele:
    #   <HRZ set_param total, 1234 />
    #   <HRZ set_param>name, John Doe</HRZ set_param>
    #
    # @param params [Array<String>] Parameter-Array
    #   params[0] = Parametername (erforderlich)
    #   params[1] = Wert (erforderlich)
    # @return [String] Leerer String (set_param gibt nichts zurück)
    def self.hrz_strfunc_set_param(params)
      param_name = params[0]
      param_value = params[1] || ""
      
      if param_name.nil? || param_name.empty?
        error_msg = "set_param: parameter name is required"
        TagStringHelper.report_error(error_msg, { function: 'set_param', params: params })
        raise HrzError.new(error_msg, { function: 'set_param', params: params })
      end
      
      # Context setzen
      Thread.current[:hrz_context] ||= {}
      Thread.current[:hrz_context][param_name.to_sym] = param_value
      
      Rails.logger.debug "Parameter '#{param_name}' set to '#{param_value}'"
      
      # set_param gibt keinen Text zurück
      ""
    end
    
    # ============================================================================
    # Hilfsmethoden für Context-Management
    # ============================================================================
    
    # Initialisiert den Kontext für eine neue Verarbeitung
    # @param initial_context [Hash] Initialer Kontext
    def self.initialize_context(initial_context = {})
      Thread.current[:hrz_context] = initial_context.dup
    end
    
    # Gibt den aktuellen Kontext zurück
    # @return [Hash] Aktueller Kontext
    def self.current_context
      Thread.current[:hrz_context] || {}
    end
    
    # Bereinigt den Kontext nach der Verarbeitung
    def self.clear_context
      Thread.current[:hrz_context] = nil
    end
    
    # Setzt einen Wert im Kontext
    # @param key [Symbol, String] Schlüssel
    # @param value [Object] Wert
    def self.set_context_value(key, value)
      Thread.current[:hrz_context] ||= {}
      Thread.current[:hrz_context][key.to_sym] = value
    end
    
    # Liest einen Wert aus dem Kontext
    # @param key [Symbol, String] Schlüssel
    # @param default [Object] Defaultwert wenn nicht vorhanden
    # @return [Object] Wert oder Default
    def self.get_context_value(key, default = nil)
      context = Thread.current[:hrz_context] || {}
      context[key.to_sym] || default
    end
  end
end