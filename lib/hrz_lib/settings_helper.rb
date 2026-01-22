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
# Purpose: Helper module for accessing HRZ Lib plugin settings
# Location: lib/hrz_lib/settings_helper.rb

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
# Purpose: Helper module for accessing HRZ Lib plugin settings
# Location: lib/hrz_lib/settings_helper.rb

module HrzLib
  module SettingsHelper
    # Cache for settings to avoid repeated database queries
    @settings_cache = nil
    @cache_time = nil
    CACHE_TTL_S = 60 # Cache for 60 seconds


    # Get all plugin settings as a hash
    # @param force_reload [Boolean] Force reload from database, even if CACHE_TTL_S is not over yet?
    # @return [Hash] Plugin settings
    def self.get_settings(force_reload: false)
      if force_reload || @cache_time.nil? || (Time.now - @cache_time) > CACHE_TTL_S
        reload_settings
      end
      @settings_cache
    end  # get_settings


    # Reload settings from database and update cache
    # @return [Hash] Reloaded settings
    def self.reload_settings
      settings = Setting.plugin_hrz_lib || {}
      #HrzLogger.logger.info_msg "SettingsHelper.reload_settings: " + settings.inspect

      @settings_cache = {
        debug_user_id:                                     settings['debug_user_id'].to_i,
        q_verbose_log:                 settings_to_boolean(settings['q_verbose_log']),
        q_verbose_issue_helper:        settings_to_boolean(settings['q_verbose_issue_helper']),
        q_verbose_custom_field_helper: settings_to_boolean(settings['q_verbose_custom_field_helper']),
        q_verbose_parser:              settings_to_boolean(settings['q_verbose_parser']),
        q_verbose_tag_functions:       settings_to_boolean(settings['q_verbose_tag_functions']),
        q_verbose_http_requests:       settings_to_boolean(settings['q_verbose_http_requests']),
        q_redirect_emails:             settings_to_boolean(settings['q_redirect_emails'])
      }
      @cache_time = Time.now
      @settings_cache
    end  #reload_settings


    # Convert the given setting to a boolean value.
    # @param  val [String, Boolean, Integer] Settings value
    # @return     [Boolean]                  Settings value converted to Boolean.
    def self.settings_to_boolean(val)
      val == 'true'  ||  val == 1  ||  val == true
    end  # settings_to_boolean


    # Clear the settings cache.
    # You can do that to trigger a reload upon next usage.
    def self.clear_cache
      @settings_cache = nil
      @cache_time = nil
    end  # clear_cache


    # Check if verbose logging is enabled for the current user and specific area
    # @param user_id [Integer] Current user ID
    # @param area    [Symbol]  Area to check (:main, :issue_helper, :custom_field_helper, :parser, :tag_functions, :http_requests)
    # @return [Boolean] True if logging should be verbose.
    def self.verbose_log?(user_id, area)
      settings = get_settings

      # If debug_user_id is set and doesn't match, return false
      return false if settings[:debug_user_id] > 0 && settings[:debug_user_id] != user_id

      # Check main switch
      return false unless settings[:q_verbose_log]

      # Check specific area
      case area
        when :main
          true   # Already checked above
        when :issue_helper
          settings[:q_verbose_issue_helper]
        when :custom_field_helper
          settings[:q_verbose_custom_field_helper]
        when :parser
          settings[:q_verbose_parser]
        when :tag_functions
          settings[:q_verbose_tag_functions]
        when :http_requests
          settings[:q_verbose_http_requests]
        else
          false
      end # case
    end  # verbose_log?



    # Check if emails should be redirected for the current user.
    # @param user_id [Integer] Current user ID
    # @return        [Integer] 0 if not redirecting, or User ID to redirect to.
    def self.redirect_emails(user_id)
      settings = get_settings

      # Only redirect if debug_user_id is set and redirect_emails + "main debug" are enabled
      return 0   unless settings[:debug_user_id] > 0  &&  settings[:q_redirect_emails]  &&  verbose_log?(user_id, :main)

      # Return the user ID to redirect to
      settings[:debug_user_id]
    end  # redirect_emails


    # Get a specific setting value
    # @param key [Symbol] Setting key
    # @return [Object] Setting value
    def self.get(key)
      get_settings[key]
    end  # get

  end  # module SettingsHelper
end   # module HrzLib
