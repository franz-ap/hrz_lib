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
    # @param j_ai_id    [Integer] ID of the AI model to be used for the query (hrzlib_ai_models.j_key).
    # @param b_query    [String]  Query string for the AI.
    # @param b_name_qry [String]  A short, "human readable name" that explains the reason for this query.
    #                             Used for log messages. Optional.
    # @return [String] AI's answer, or nil if an error occurred.
    def self.ai_query(j_ai_id, b_query, b_name_qry = '')
      # Load AI model configuration from database
      ai_model = HrzlibAiModel.find_by(j_key: j_ai_id)
      if ai_model.nil?
        HrzLogger.error_msg "AiHelper.ai_query: AI model with ID #{j_ai_id} not found."
        return nil
      end

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

      # Prepare POST data: Replace MY_PROMPT with the query string (properly JSON-escaped)
      b_post_data = ai_model.b_json_post.to_s.gsub('MY_PROMPT', b_query.to_json[1..-2])
      # Note: to_json adds quotes around the string, [1..-2] removes them,
      # so we get the escaped content without surrounding quotes.

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

      # Check result
      unless hsh_res[:q_ok]
        HrzLogger.error_msg "AiHelper.ai_query: HTTP request failed for #{b_name_svc}."
        return nil
      end

      # Parse response and extract answer using JSON path
      begin
        data = JSON.parse(hsh_res[:body])
        if ai_model.b_json_res_path.present?
          result = JsonPath.on(data, ai_model.b_json_res_path).first
        else
          # No path configured, return entire response
          result = hsh_res[:body]
        end
        result.to_s
      rescue JSON::ParserError => e
        HrzLogger.error_msg "AiHelper.ai_query: Failed to parse JSON response: #{e.message}"
        nil
      rescue => e
        HrzLogger.error_msg "AiHelper.ai_query: Failed to extract result using path '#{ai_model.b_json_res_path}': #{e.message}"
        nil
      end
    end

  end
end
