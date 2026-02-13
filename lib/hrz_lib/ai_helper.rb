#-------------------------------------------------------------------------------------------#
# Redmine utility/library plugin. Provides common functions to other plugins + REST API.    #
# Copyright (C) 2026 Franz Apeltauer                                                        #
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
# Purpose: Helper methods for AI model queries

require 'json'
require 'jsonpath'

module HrzLib
  class AiHelper

    # Perform an AI query using a configured AI model.
    # Reads the AI model configuration from the database, prepares the HTTP request
    # with proper headers and POST data, sends the request, and extracts the answer
    # from the response using the configured JSON path.
    #
    # @param j_ai_id    [Integer] ID of the AI model to be used for the query (hrzlib_ai_models.j_key in the database).
    # @param b_query    [String]  Query string for the AI.
    # @param b_name_qry [String]  A short, "human readable name" that explains the reason for this query.
    #                             Used for log messages. Optional.
    # @return [String] AI's answer, or nil if an error occurred.
    def self.ai_query(j_ai_id, b_query, b_name_qry = '')
      result = execute_ai_request(j_ai_id, b_query, b_name_qry)

      unless result[:q_ok]
        HrzLogger.error_msg "AiHelper.ai_query: #{result[:error]}"
        return nil
      end

      result[:json_path_result]
    end  # ai_query



    # Test an AI model with a sample query and return all debug details.
    # Used for testing AI model configuration in the admin interface.
    #
    # @param j_ai_id [Integer] ID of the AI model to be tested (hrzlib_ai_models.j_key in the database).
    # @param b_query [String]  Test query string for the AI. Optional, defaults to a simple test question.
    # @return [Hash] Hash containing all debug details (see execute_ai_request for details).
    def self.ai_query_test(j_ai_id, b_query = 'What is the name of Austria\'s capital?')
      HrzLib::HrzLogger.clear_messages
      execute_ai_request(j_ai_id, b_query, 'AI model test')
      # Append all error messages, that we may have seen along the way:
      result[:error] = HrzLib::HrzLogger.retrieve_msgs('error',       result[:error])
      result[:error] = HrzLib::HrzLogger.retrieve_msgs('error_abort', result[:error])
      HrzLib::HrzLogger.clear_messages
    end  # ai_query_test



    # Internal method that executes an AI request and returns all details.
    # Used by both ai_query and ai_query_test.
    #
    # @param j_ai_id    [Integer] ID of the AI model (hrzlib_ai_models.j_key in the database).
    # @param b_query    [String]  Query string for the AI.
    # @param b_name_qry [String]  A short name for this query (for logging).
    # @return [Hash] Hash containing:
    #   :q_ok             [Boolean] true if request was successful
    #   :error            [String]  Error message if q_ok is false
    #   :url              [String]  URL that was called
    #   :request_header   [Array]   HTTP headers sent with the request
    #   :post_data        [String]  POST data sent
    #   :response_code    [String]  HTTP response code
    #   :response_message [String]  HTTP response message
    #   :response_header  [Object]  HTTP response headers
    #   :response_body    [String]  Raw response body
    #   :json_path        [String]  Configured JSON path for result extraction
    #   :json_path_result [String]  Result extracted using JSON path
    #   :t_answer_s       [Float]   The time to get the answer back [s].
    def self.execute_ai_request(j_ai_id, b_query, b_name_qry = '')
      result = {
        q_ok:             false,
        error:            nil,
        url:              nil,
        request_header:   [],
        post_data:        nil,
        response_code:    nil,
        response_message: nil,
        response_header:  nil,
        response_body:    nil,
        json_path:        nil,
        json_path_result: nil,
        t_answer_s:       nil
      }

      # Load AI model configuration from database
      ai_model = HrzlibAiModel.find_by(j_key: j_ai_id)
      if ai_model.nil?
        result[:error] = "AI model with ID #{j_ai_id} not found."
        return result
      end

      result[:url] = ai_model.b_url
      result[:json_path] = ai_model.b_json_res_path

      # Build HTTP headers
      aux_hdr = []
      aux_hdr << { key: 'Content-Type', val: 'application/json' }

      # API key header (e.g., "Authorization: Bearer xxx" or "api-key: xxx")
      if ai_model.b_hdr_name_api_key.present? && ai_model.b_api_key.present?
        aux_hdr << { key: ai_model.b_hdr_name_api_key, val: ai_model.b_api_key }
      end

      # Auxiliary headers 1 and 2
      if ai_model.b_hdr_name_aux1.present? && ai_model.b_hdr_val_aux1.present?
        aux_hdr << { key: ai_model.b_hdr_name_aux1, val: ai_model.b_hdr_val_aux1 }
      end
      if ai_model.b_hdr_name_aux2.present? && ai_model.b_hdr_val_aux2.present?
        aux_hdr << { key: ai_model.b_hdr_name_aux2, val: ai_model.b_hdr_val_aux2 }
      end

      result[:request_header] = aux_hdr

      # Prepare POST data: Replace MY_PROMPT with the query string (properly JSON-escaped)
      b_post_data = ai_model.b_json_post.to_s.gsub('MY_PROMPT', b_query.to_json)
      # Note: to_json adds quotes around the string. [1..-2] would remove them, if we
      #       ever wanted to get the escaped content without surrounding quotes.
      result[:post_data] = b_post_data

      # Service name for logging
      b_name_svc = b_name_qry.present? ? "AI query '#{b_name_qry}'" : 'AI query'

      # Perform HTTP request
      hsh_res = HrzLib::HrzHttp.http_request(
        ai_model.b_url,
        'POST',
        aux_hdr,
        b_post_data,
        b_name_svc
      )

      result[:response_code]    = hsh_res[:response_code]
      result[:response_message] = hsh_res[:response_message]
      result[:response_header]  = hsh_res[:response_header]
      result[:response_body]    = hsh_res[:body]
      result[:t_answer_s]       = hsh_res[:t_answer_s]

      unless hsh_res[:q_ok]
        result[:error] = "HTTP request failed: #{hsh_res[:response_code]} #{hsh_res[:response_message]}"
        return result
      end

      # Parse response and extract answer using JSON path
      begin
        data = JSON.parse(hsh_res[:body])
        if ai_model.b_json_res_path.present?
          result[:json_path_result] = JsonPath.on(data, ai_model.b_json_res_path).first.to_s
        else
          # No path configured, return entire response
          result[:json_path_result] = hsh_res[:body]
        end
        result[:q_ok] = true
      rescue JSON::ParserError => e
        result[:error] = "Failed to parse JSON response: #{e.message}"
      rescue => e
        result[:error] = "Failed to extract result using path '#{ai_model.b_json_res_path}': #{e.message}"
      end

      result
    end  #                execute_ai_request

    private_class_method :execute_ai_request

  end  # class AiHelper
end  # module HrzLib
