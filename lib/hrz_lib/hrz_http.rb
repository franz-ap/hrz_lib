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
# Purpose: Perform http/https requests, etc..

require 'net/http'
require 'json'
require 'uri'

module HrzLib
  class HrzHttp

    # Perform HTTP request.
    # @param b_url       [String]      URL to be called. nil or empty is ok, will return q_ok=false and an empty body.
    # @param b_method    [String]      Method to be used: 'GET', 'PUT', 'POST', ... Optional.
    # @param aux_hdr     [Array, Hash] Auxiliary HTTP header lines, optional:
    #                                  In an Array:  [ {key: 'aux_key1', val: 'aux_value1'}, {key: 'aux_key2', val: 'aux_value2'} ]
    #                                  In a Hash:    {        aux_key1:        aux_value1,          aux_key2:        aux_value2   }
    # @param b_post_data [String]      Data to be sent in the request body of a POST. Optional.
    # @param b_name_svc  [String]      "Human readable name" of service to be called. For messages. Optional.
    # @param arr_resp_ok [Array of Integer] HTTP response codes, that should be taken as ok, if the standard 200 is not enough.
    # @return [Hash]:
    #   :q_ok [Boolean] ... true:  Success, HTTP request done. The result body is in :body
    #                       false: Error, problems or there was no URL, i.e. nothing to do. :body is empty or at least unusable. Error messages were already issued.
    #   :body [String] .... The body of the HTTP response.
    #
    # Examples:
    #   a) aux_hdr Array
    #   hsh_res = HrzLib::HrzHttp.http_request('https://redm.xy/info.json',
    #                                          'GET',
    #                                          [{key: 'X-Redmine-API-Key', val: api_key},
    #                                           {key: 'Content-Type',      val: 'application/json'}
    #                                          ],
    #                                          nil,
    #                                          'instance_info')
    #   if hsh_res[:q_ok]
    #     data = JSON.parse(hsh_res[:body])
    #     ...
    #   end
    #
    #   b) aux_hdr Hash
    #   hsh_res = HrzLib::HrzHttp.http_request('https://redm.xy/info.json',
    #                                          'GET',
    #                                          {'X-Redmine-API-Key' => api_key, 'Content-Type' => 'application/json'},
    #                                          nil,
    #                                          'instance_info')
    #   if hsh_res[:q_ok]
    #     data = JSON.parse(hsh_res[:body])
    #     ...
    #   end
    def self.http_request(b_url,                # URL to be called. nil or empty is ok, will return q_ok=false and an empty body.
                          b_method     = 'GET', # Method to be used: 'GET', 'PUT', 'POST', ...
                          aux_hdr      = [],    # Array of auxiliary HTTP header lines: {key: 'aux_key1', val: 'aux_value1'}
                          b_post_data  = '',    # Data to be sent in the request body of a POST.               Optional.
                          b_name_svc   = '',    # "Human readable name" of service to be called. For messages. Optional.
                          arr_resp_ok  = [200]) # HTTP response codes, that should be taken as ok.
      HrzLogger.debug_msg "HrzHttp.http_request: #{b_method.to_s} #{b_url.to_s}" + (b_name_svc.empty? ? '' : ' / Service ') + b_name_svc
      t_start = Time.now
      hsh_result = { q_ok: true, body: '' }
      return { q_ok: false, body: '' }  if b_url.nil? || b_url.empty?
      begin
        uri  = URI.parse(b_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true  if uri.scheme == 'https'
        http.open_timeout = 30  # Open timeout [s]: maximum time to establish a connection.
        http.read_timeout = 90  # Read timeout [s]: maximum time to wait for a response.
        # Method
        case b_method
          when 'GET'
               request = Net::HTTP::Get.new(uri)
          when 'PUT'
               request = Net::HTTP::Put.new(uri)
          when 'POST'
               request = Net::HTTP::Post.new(uri)
               request.body = b_post_data  if ! b_post_data.nil?
          else
               request = nil
               HrzLogger.error_msg "Unimplemented REST method #{b_method} in HrzHttp.http_request" + (b_name_svc.empty? ? '' : ' / service ') + b_name_svc + '. Please inform an admin.'
               hsh_result[:q_ok] = false
        end
        if ! request.nil?
          # Auxiliary HTTP header lines
          if aux_hdr.is_a?(Array)
            for aux_hdr1 in aux_hdr
              request[ aux_hdr1[:key] ] = aux_hdr1[:val]
            end
          elsif aux_hdr.is_a?(Hash)
            request.merge!(aux_hdr)
          else
            HrzLogger.debug_msg "HrzHttp.http_request: Unsupported object type  #{aux_hdr.class.name} of aux_hdr. Ignoring it."
          end
          # Send the request
          response = http.request(request)
          # Check the answer
          if arr_resp_ok.include?(response.code.to_i)
            # Ok
            hsh_result[:body] = response.body
          else
            HrzLogger.error_msg "Request" + (b_name_svc.empty? ? '' : ' for service ') +  b_name_svc + " failed with HTTP code: #{response.code} - #{response.message}.  URL: #{b_url} Result: #{response.body}"
            # Response herader:
            response.each_header { |key, value| HrzLogger.debug_msg "  #{key}: #{value}" }
            hsh_result[:q_ok] = false
          end
        end
      rescue => exc
        HrzLogger.error_msg (b_name_svc.empty? ? 'Requested service' : 'Service ') +  b_name_svc + " for Tkt_summary_AI CustWorkflow is currently unavailable: '#{exc.message}'"
        hsh_result[:q_ok] = false
      end
      HrzLogger.debug_msg "HrzHttp.http_request" + (b_name_svc.empty? ? '' : ' for service ') +  b_name_svc + " finished: ok=#{hsh_result[:q_ok].to_s}. It took #{Time.now - t_start} s  body: " + hsh_result[:body].inspect
      hsh_result
    end  # http_request


  end  # class HrzHttp
end  # module HrzLib
