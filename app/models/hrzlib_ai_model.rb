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
# Purpose: Model for AI model settings


class HrzlibAiModel < ActiveRecord::Base
  self.primary_key = 'j_key'

  # Name of the Custom Field that defines the available AI models.
  AI_MODEL_CF_NAME = 'AI Model'

  belongs_to :creator, class_name: 'User', foreign_key: 'created_by', optional: true
  belongs_to :updater, class_name: 'User', foreign_key: 'updated_by', optional: true

  validates :j_key, presence: true, uniqueness: true
  validates :b_url, length: { maximum: 1000 }
  validates :b_api_key, length: { maximum: 100 }
  validates :b_json_post, length: { maximum: 4000 }
  validates :b_json_res_path, length: { maximum: 100 }
  validates :b_hdr_name_api_key, length: { maximum: 30 }
  validates :b_hdr_name_aux1, length: { maximum: 30 }
  validates :b_hdr_val_aux1, length: { maximum: 100 }
  validates :b_hdr_name_aux2, length: { maximum: 30 }
  validates :b_hdr_val_aux2, length: { maximum: 100 }
  validates :b_comment, length: { maximum: 4000 }

  before_create :set_created_by
  before_save :set_updated_by
  # REMOVED auto_fill_b_key from before_save to avoid issues during migration

  # Returns a Hash of available AI models from the ProjectCustomField.
  # Format: { "display_name" => key_integer, ... }
  # Used by the controller for dropdown population and by AiHelper for model name lookup.
  # @return [Hash] Available AI models as { name => key }, or {} on error.
  def self.fetch_available_models
    field = HrzLib::CustomFieldHelper.get_custom_field(ProjectCustomField.find_by(name: AI_MODEL_CF_NAME)&.id)
    if field && field[:possible_val_keys] && field[:possible_values]
      field[:possible_values].zip(field[:possible_val_keys]).to_h
    else
      {}
    end
  rescue => e
    Rails.logger.error "Error fetching AI models: #{e.message}"
    {}
  end

  # Returns the Custom Field display name for a given AI model key.
  # @param j_key [Integer] The AI model key (j_key).
  # @return [String, nil] The display name, or nil if not found.
  def self.model_name_for_key(j_key)
    fetch_available_models.key(j_key)
  end

  private

  def set_created_by
    self.created_by = User.current.id if User.current
  end

  def set_updated_by
    self.updated_by = User.current.id if User.current
  end

  # This method can be called manually when needed
  def auto_fill_b_key
    return unless j_key.present?

    begin
      models = self.class.fetch_available_models
      name = models.key(j_key)
      self.b_key = name if name
    rescue => e
      Rails.logger.error "Error auto-filling b_key: #{e.message}"
    end
  end
end  # class HrzlibAiModel
