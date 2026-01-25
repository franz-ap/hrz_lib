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
# Purpose: Helper module for creating and managing Redmine custom fields.

module HrzLib
  module CustomFieldHelper

# Creates a new custom field
    #
    # @param name [String] The name of the custom field
    # @param field_format [String] The format type: 'string', 'text', 'int', 'float', 'date',
    #   'bool', 'list', 'user', 'version', 'link', 'attachment', 'enumeration'
    # @param customized_type [String] What the field applies to: 'issue', 'project', 'user',
    #   'time_entry', 'version', 'document', 'group'
    # @param options [Hash] Additional options for the custom field
    # @option options [String] :description Description of the field
    # @option options [Boolean] :is_required Whether the field is required (default: false)
    # @option options [Boolean] :is_for_all Whether field is for all projects (default: true)
    # @option options [Boolean] :visible Whether field is visible (default: true)
    # @option options [Boolean] :searchable Whether field is searchable (default: false)
    # @option options [Boolean] :multiple Whether multiple values allowed for list fields (default: false)
    # @option options [String] :default_value Default value for the field
    # @option options [String] :regexp Regular expression for validation
    # @option options [Integer] :min_length Minimum length for text fields
    # @option options [Integer] :max_length Maximum length for text fields
    # @option options [Array<String>] :possible_values Array of possible values for list fields
    # @option options [Array<Hash>] :enumerations Array of enumeration hashes with :name and optionally :active (default: true) and :position. :id allowed, but ignored.
    # @option options [Array<Integer>] :project_ids Array of project IDs if is_for_all is false
    # @option options [Array<Integer>] :tracker_ids Array of tracker IDs (for issue custom fields)
    # @option options [Array<String>] :role_ids Array of role IDs that can see/edit the field
    # @option options [String] :formula Ruby formula for computed custom fields (requires Computed Custom Field plugin)
    # @option options [Boolean] :is_computed Whether this is a computed field (default: false, requires plugin)
    # @param q_verbose [Boolean] Be verbose? Default: false
    #
    # @return [Integer, nil] The ID of the created custom field, or nil if creation failed
    #
    # @example Create a simple text field
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Customer Name',
    #     'string',
    #     'issue',
    #     is_required: true
    #   )
    #
    # @example Create a select list field
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Priority Level',
    #     'list',
    #     'issue',
    #     possible_values: ['Low', 'Medium', 'High', 'Critical'],
    #     default_value: 'Medium'
    #   )
    #
    # @example Create a multi-select list
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Tags',
    #     'list',
    #     'issue',
    #     possible_values: ['Bug', 'Feature', 'Enhancement', 'Documentation'],
    #     multiple: true
    #   )
    #
    # @example Create an enumeration field. a) enumerations passed in an Array of Hashes
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Status',
    #     'enumeration',
    #     'issue',
    #     enumerations: [
    #       { name: 'Active', position: 1 },
    #       { name: 'Inactive', position: 2, active: false },
    #       { name: 'Pending', position: 3 }
    #     ]
    #   )
    #
    # @example Create a date field with validation
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Deadline',
    #     'date',
    #     'issue',
    #     is_required: true,
    #     description: 'Final deadline for this task'
    #   )
    #
    # @example Create a computed field (requires Computed Custom Field plugin)
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Total Cost',
    #     'float',
    #     'issue',
    #     is_computed: true,
    #     formula: 'cfs[1] * cfs[2]',
    #     description: 'Quantity * Unit Price'
    #   )
    #
    # @example Create a computed field with conditional logic
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Discounted Price',
    #     'float',
    #     'issue',
    #     is_computed: true,
    #     formula: 'if cfs[5].to_i > 100; cfs[5] * 0.9; else; cfs[5]; end'
    #   )
    #
    # @example Create a key/value custom field
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Configuration Settings',
    #     'key_value',
    #     'issue',
    #     description: 'Key-value pairs for configuration'
    #   )
    #
    # @example Create key/value field with default values
    #   field_id = HrzLib::CustomFieldHelper.create_custom_field(
    #     'Environment Variables',
    #     'key_value',
    #     'project',
    #     default_value: "API_KEY=\nDATABASE_URL=\nLOG_LEVEL=info"
    #   )
    def self.create_custom_field(name, field_format, customized_type, options = {}, q_verbose = false)
      q_verbose_cf = q_verbose  ||  SettingsHelper.verbose_log?(User.current&.id, :custom_field_helper)
      HrzLogger.debug_msg "HRZ Lib create_custom_field(name='#{name}', field_format='#{field_format}', customized_type='#{customized_type}', options=#{options.inspect}"  if q_verbose_cf
      begin
        # Validate field_format
        valid_formats = %w[string text int float date bool list user version link attachment key_value enumeration]
        unless valid_formats.include?(field_format)
          HrzLogger.error_msg "HRZ Lib create_custom_field: Invalid field format '#{field_format}'. Valid formats: #{valid_formats.join(', ')}"
          return nil
        end

        # Validate customized_type
        valid_types = %w[issue project user time_entry version document group]
        unless valid_types.include?(customized_type)
          HrzLogger.error_msg "HRZ Lib create_custom_field: Invalid customized type '#{customized_type}'. Valid types: #{valid_types.join(', ')}"
          return nil
        end

        # Determine the appropriate CustomField class based on type
        klass = case customized_type
                when 'issue'
                  IssueCustomField
                when 'project'
                  ProjectCustomField
                when 'user'
                  UserCustomField
                when 'time_entry'
                  TimeEntryCustomField
                when 'version'
                  VersionCustomField
                when 'document'
                  DocumentCustomField
                when 'group'
                  GroupCustomField
                else
                  CustomField
                end

        # Create the custom field
        custom_field = klass.new
        custom_field.name = name
        custom_field.field_format = field_format

        # Set standard options with defaults
        custom_field.description = options[:description] if options[:description]
        custom_field.is_required = options[:is_required] || false
        custom_field.is_for_all = options.key?(:is_for_all) ? options[:is_for_all] : true
        custom_field.visible = options.key?(:visible) ? options[:visible] : true
        custom_field.searchable = options[:searchable] || false
        custom_field.multiple = options[:multiple] || false
        custom_field.default_value = options[:default_value] if options[:default_value]

        # Set validation options
        custom_field.regexp = options[:regexp] if options[:regexp]
        custom_field.min_length = options[:min_length] if options[:min_length]
        custom_field.max_length = options[:max_length] if options[:max_length]

        # Set possible values for list fields
        if field_format == 'list' && options[:possible_values]
          custom_field.possible_values = options[:possible_values]
        end

        # Set projects if not for all
    #    if !custom_field.is_for_all && options[:project_ids]
     #     custom_field.project_ids = options[:project_ids]
      #  end     TODO names / only text identifiers

        # Set trackers for issue custom fields
        if customized_type == 'issue'
          if options[:trackers]
            # Verify tracker names, adjusting IDs, if necessary
            arr_tracker_ids = []
            options[:trackers].each do |hsh_trk|
              tracker = Tracker.find_by(name: hsh_trk[:name])
              if tracker
                arr_tracker_ids << tracker.id
                if hsh_trk[:id] != tracker.id
                  HrzLogger.info_msg "HRZ Lib create_custom_field: Adjusted tracker '#{hsh_trk[:name]}'s ID #{hsh_trk[:id]} --> #{tracker.id} before adding it to CF."
                end
              else
                HrzLogger.warning_msg "HRZ Lib create_custom_field: Tracker '#{hsh_trk[:name]}' does not exist. Skipping it."
              end
            end
            options[:tracker_ids] = arr_tracker_ids  # Overwrite :tracker_ids in options, in case they were passed. Prefer :trackers, if we have both. Safer.
          end
          if options[:tracker_ids]
            custom_field.tracker_ids = options[:tracker_ids]
          end
        end # if customized_type == 'issue'

        # Set roles if specified
        if options[:role_ids]
          custom_field.role_ids = options[:role_ids]
        end

        # Set formula for computed custom fields (requires Computed Custom Field plugin)
        if options[:is_computed] && options[:formula]
          if custom_field.respond_to?(:formula=)
            custom_field.formula = options[:formula]
            HrzLogger.info_msg "HRZ Lib create_custom_field: Setting formula for computed custom field: #{options[:formula]}"  if q_verbose_cf
          else
            HrzLogger.warning_msg "HRZ Lib create_custom_field: Computed Custom Field plugin not detected. Formula will be ignored."
            HrzLogger.warning_msg "HRZ Lib create_custom_field: Install the plugin from: https://github.com/annikoff/redmine_plugin_computed_custom_field"
          end
        elsif options[:formula] && !options[:is_computed]
          HrzLogger.warning_msg "HRZ Lib create_custom_field: Formula provided but is_computed not set to true. Formula will be ignored."
        end

        # Save the custom field
        if custom_field.save
          HrzLogger.info_msg "HRZ Lib create_custom_field: Successfully created custom field '#{name}' (ID: #{custom_field.id})"  if q_verbose_cf

          # Handle enumerations for enumeration field format ---------------------
          if field_format == 'enumeration'
            if custom_field.respond_to?(:enumerations)
              # Redmine 4.x and later - use enumerations_attributes
              if options[:enumerations]
                # a) from enumerations Array of Hashes
                options[:enumerations].each_with_index do |enum, index|
                  #custom_field.enumerations.build(
                  CustomFieldEnumeration.create!(
                        custom_field_id: custom_field.id,
                        name:            enum[:name],
                        active:          (enum.key?(:active) ? enum[:active] : true),
                        position:        enum[:position] || (index + 1)
                      )
                end
              elsif options[:possible_values]
                # b) from Array of possible_values. Optional: possible_val_active
                arr_possible_val_active = options[:possible_val_active] || []
                options[:possible_values].each_with_index do |val, index|
                  #custom_field.enumerations.build(
                  CustomFieldEnumeration.create!(
                        custom_field_id: custom_field.id,
                        name:            val,
                        active:          (arr_possible_val_active[index].nil? ? true : arr_possible_val_active[index]),
                        position:        (index + 1)
                      )
                end
              else
                HrzLogger.warning_msg "HRZ Lib create_custom_field '#{name}', type enumeration: Neither enumerations nor possible values given. Created it without values."
              end
              #HrzLogger.info_msg "HRZ Lib create_custom_field: Set #{custom_field.enumerations.length} enumerations for field '#{name}': #{custom_field.enumerations.inspect}"  if q_verbose_cf
           # elsif custom_field.respond_to?(:custom_options_attributes)
           #   # Alternative method for custom options
           #   custom_options_attrs = {}
           #   if options[:enumerations]
           #     # a) from enumerations Array of Hashes
           #     options[:enumerations].each_with_index do |enum, index|
           #       custom_options_attrs[index.to_s] = {
           #             value:    enum[:name],
           #             position: enum[:position] || (index + 1)
           #           }
           #     end
           #   elsif options[:possible_values]
           #     # b) from Array of possible_values.
           #     arr_possible_val_active = options[:possible_val_active] || []
           #     options[:possible_values].each_with_index do |val, index|
           #       custom_options_attrs[index.to_s] = {
           #             value:    val,
           #             position: (index + 1)
           #           }
           #     end
           #   else
           #     HrzLogger.warning_msg "HRZ Lib create_custom_field '#{name}', type enumeration: Neither enumerations nor possible values given. Creating it without values."
           #   end
           #   custom_field.custom_options_attributes = custom_options_attrs
           #   HrzLogger.info_msg "HRZ Lib create_custom_field: Set #{options[:enumerations].length} custom options for field '#{name}'"  if q_verbose_cf
           # else
           #   HrzLogger.warning_msg "HRZ Lib create_custom_field: Enumeration format requested but enumerations_attributes not supported in this Redmine version. Falling back to possible_values if available."
           #   if options[:possible_values]
           #     custom_field.possible_values = options[:possible_values]
           #   elsif options[:enumerations]
           #     # Extract names from enumerations as fallback
           #     custom_field.possible_values = options[:enumerations].map { |e| e[:name] }
           #   end
            end
          end # if field_format == 'enumeration' ---------------------------------

          return custom_field.id
        else
          HrzLogger.error_msg "HRZ Lib create_custom_field: Failed to create custom field: #{custom_field.errors.full_messages.join(', ')}"
          return nil
        end

      rescue => e
        HrzLogger.error_msg "HRZ Lib create_custom_field: Error creating custom field: #{e.message}"
        HrzLogger.error_msg e.backtrace.join("\n")
        return nil
      end
    end  # create_custom_field

    # Updates an existing custom field
    #
    # @param custom_field_id [Integer] The ID of the custom field to update
    # @param attributes [Hash] Hash of attributes to update
    # @option attributes [String] :name New name
    # @option attributes [String] :description New description
    # @option attributes [Boolean] :is_required New required status
    # @option attributes [Boolean] :visible New visibility
    # @option attributes [Boolean] :searchable New searchable status
    # @option attributes [String] :default_value New default value
    # @option attributes [Array<String>] :possible_values New possible values (for list fields)
    # @option attributes [Array<Integer>] :project_ids New project IDs
    # @option attributes [Array<Integer>] :tracker_ids New tracker IDs
    # @option attributes [String] :formula New formula (for computed fields)
    #
    # @return [Boolean] true if update was successful, false otherwise
    #
    # @example Update field description
    #   success = HrzLib::CustomFieldHelper.update_custom_field(
    #     5,
    #     description: 'Updated description',
    #     is_required: true
    #   )
    #
    # @example Update computed field formula
    #   success = HrzLib::CustomFieldHelper.update_custom_field(
    #     5,
    #     formula: 'cfs[1] * cfs[2] * 1.19'
    #   )
    #
    def self.update_custom_field(custom_field_id, attributes = {})
      begin
        custom_field = CustomField.find(custom_field_id)

        # Update attributes
        attributes.each do |key, value|
          custom_field.send("#{key}=", value) if custom_field.respond_to?("#{key}=")
        end

        if custom_field.save
          Rails.logger.info "HRZ Lib: Successfully updated custom field ##{custom_field_id}"
          return true
        else
          Rails.logger.error "HRZ Lib: Failed to update custom field: #{custom_field.errors.full_messages.join(', ')}"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "HRZ Lib: Custom field not found: #{e.message}"
        return false
      rescue => e
        Rails.logger.error "HRZ Lib: Error updating custom field: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return false
      end
    end  # update_custom_field



    # Deletes a custom field
    #
    # @param custom_field_id [Integer] The ID of the custom field to delete
    #
    # @return [Boolean] true if deletion was successful, false otherwise
    #
    # @example Delete custom field
    #   success = HrzLib::CustomFieldHelper.delete_custom_field(5)
    #
    def self.delete_custom_field(custom_field_id)
      begin
        custom_field = CustomField.find(custom_field_id)

        if custom_field.destroy
          Rails.logger.info "HRZ Lib: Successfully deleted custom field ##{custom_field_id}"
          return true
        else
          Rails.logger.error "HRZ Lib: Failed to delete custom field"
          return false
        end

      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "HRZ Lib: Custom field not found: #{e.message}"
        return false
      rescue => e
        Rails.logger.error "HRZ Lib: Error deleting custom field: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return false
      end
    end  # delete_custom_field



    # Gets details of a custom field
    #
    # @param custom_field_id [Integer] The ID of the custom field.
    # @return [Hash, nil] Hash with custom field details, or nil on error
    #
    # @example Get field details
    #   field = HrzLib::CustomFieldHelper.get_custom_field(5)
    #   puts field[:name]
    #   puts field[:trackers].map(&:name)
    #
    # If you know the name, but not the ID of a custom field, you can use
    # these methods to find it:
    # a) For custom fields in issues: IssueCustomField.find_by(name: 'My field')
    #      cf = IssueCustomField.find_by(name: 'My field')
    #      cf_id = cf&.id
    #      field = HrzLib::CustomFieldHelper.get_custom_field(cf_id)
    #      puts field[:possible_values]
    #    All in one line:
    #      field = HrzLib::CustomFieldHelper.get_custom_field(IssueCustomField.find_by(name: 'My field')&.id)
    #    Note: Many, but not all properties of custom fields are available
    #          in the above cf. So, may not need the 2nd call.
    # b) For custom fields in projects: ProjectCustomField.find_by(name: 'My field')
    # c) Similar for other custom fields:
    #    DocumentCategoryCustomField, DocumentCustomField, GroupCustomField,
    #    IssuePriorityCustomField, TimeEntryActivityCustomField, TimeEntryCustomField,
    #    UserCustomField, VersionCustomField
    #    Details can be found at
    #      https://www.rubydoc.info/github/redmine/redmine/CustomField
    # d) If you do not know the type or if you want to search for any kind of
    #    custom field: CustomField.find_by(name: 'My field')
    #    Please be aware, that custom field names may not be unique across types.
    #    So, better use a)-c) if possible.
    def self.get_custom_field(custom_field_id)
      q_verbose_cf = SettingsHelper.verbose_log?(User.current&.id, :custom_field_helper)
      begin
        custom_field = CustomField.find(custom_field_id)
        result = {
          id:              custom_field.id,
          type:            custom_field.type,
          customized_type: custom_field.class.name.gsub('CustomField', '').downcase,
          name:            custom_field.name,
          description:     custom_field.description,
          field_format:    custom_field.field_format,
          is_required:     custom_field.is_required,
          is_for_all:      custom_field.is_for_all,
          is_filter:       custom_field.is_filter,
          position:        custom_field.position,
          searchable:      custom_field.searchable,
          editable:        custom_field.editable,
          visible:         custom_field.visible,
         #is_for_new:      custom_field.is_for_new,
         #hint:            custom_field.hint,
          multiple:        custom_field.multiple,
          default_value:   custom_field.default_value,
          possible_values: custom_field.possible_values,
          regexp:          custom_field.regexp,
          min_length:      custom_field.min_length,
          max_length:      custom_field.max_length,
          formula:         custom_field.respond_to?(:formula) ? custom_field.formula : nil
        }

        # Get tracker information for IssueCustomFields:
        #   trackers ...... Array with Tracker ID and name.
        #   tracker_ids ... Array of Tracker IDs only, for simple access.
        if custom_field.is_a?(IssueCustomField)
          result[:trackers] = custom_field.trackers.map do |tracker|
            {
              id:   tracker.id,
              name: tracker.name
            }
          end
          result[:tracker_ids] = custom_field.tracker_ids
        end

        # Get possible values for key/value fields
        if custom_field.field_format == 'enumeration'
          if custom_field.respond_to?(:enumerations)
            # Redmine 4.x and later
            possible_values     = custom_field.enumerations.map(&:name)
            possible_val_keys   = custom_field.enumerations.map(&:id)
            possible_val_active = custom_field.enumerations.map(&:active)
            HrzLogger.info_msg "HRZ Lib get_custom_field #{custom_field.id} - '#{custom_field.name}' enumerations: #{custom_field.enumerations.inspect}"  if q_verbose_cf
          elsif custom_field.respond_to?(:custom_options)
            # Alternative method
            possible_values     = custom_field.custom_options.map(&:value)
            possible_val_keys   = custom_field.custom_options.map(&:key)
            possible_val_active = []
          elsif custom_field.respond_to?(:possible_values) && custom_field.possible_values.is_a?(Array)
            # Fallback for older versions or direct array
            possible_values     = custom_field.possible_values
            possible_val_keys   = []
            possible_val_active = []
          end
          result[:possible_values]     = possible_values
          result[:possible_val_keys]   = possible_val_keys
          result[:possible_val_active] = possible_val_active
        end

        #Rails.logger.info "HRZ Lib: Retrieved custom field ##{custom_field_id}"
        return result

      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "HRZ Lib: Custom field not found: #{e.message}"
        return nil
      rescue => e
        Rails.logger.error "HRZ Lib: Error getting custom field: #{e.message}"
        return nil
      end
    end  # get_custom_field



    # Lists all custom fields, optionally filtered by type
    #
    # @param customized_type [String, nil] Filter by type ('issue', 'project', etc.)
    #
    # @return [Array<Hash>] Array of custom field hashes
    #
    # @example Get all issue custom fields
    #   fields = HrzLib::CustomFieldHelper.list_custom_fields('issue')
    #
    def self.list_custom_fields(customized_type = nil)
      begin
        if customized_type
          klass = case customized_type
                  when 'issue' then IssueCustomField
                  when 'project' then ProjectCustomField
                  when 'user' then UserCustomField
                  when 'time_entry' then TimeEntryCustomField
                  when 'version' then VersionCustomField
                  when 'document' then DocumentCustomField
                  when 'group' then GroupCustomField
                  else CustomField
                  end
          fields = klass.all
        else
          fields = CustomField.all
        end

        result = fields.map do |cf|
          {
            id: cf.id,
            name: cf.name,
            field_format: cf.field_format,
            customized_type: cf.class.name.gsub('CustomField', '').downcase,
            is_required: cf.is_required,
            visible: cf.visible,
            is_computed: cf.respond_to?(:formula) && !cf.formula.blank?
          }
        end

        Rails.logger.info "HRZ Lib: Listed #{result.length} custom fields"
        return result

      rescue => e
        Rails.logger.error "HRZ Lib: Error listing custom fields: #{e.message}"
        return []
      end
    end  # list_custom_fields



    # ------------------------------------------------------------------------------------------------------------------------------
    # Computed Custom Fields
    # ------------------------------------------------------------------------------------------------------------------------------

    # Creates a computed custom field (requires Computed Custom Field plugin)
    #
    # @param name [String] The name of the computed field
    # @param field_format [String] The output format: 'string', 'text', 'int', 'float', 'date',
    #   'bool', 'link'
    # @param customized_type [String] What the field applies to: 'issue', 'project', 'user', etc.
    # @param formula [String] Ruby formula for computation (use cfs[cf_id] to reference other fields)
    # @param options [Hash] Additional options (same as create_custom_field)
    #
    # @return [Integer, nil] The ID of the created computed field, or nil if creation failed
    #
    # @example Simple calculation
    #   field_id = HrzLib::CustomFieldHelper.create_computed_field(
    #     'Total Cost',
    #     'float',
    #     'issue',
    #     'cfs[1] * cfs[2]',
    #     description: 'Quantity multiplied by Unit Price'
    #   )
    #
    # @example With conditional logic
    #   field_id = HrzLib::CustomFieldHelper.create_computed_field(
    #     'Discounted Price',
    #     'float',
    #     'issue',
    #     'if cfs[5].to_i > 100; cfs[5] * 0.9; else; cfs[5]; end',
    #     description: '10% discount for quantities over 100'
    #   )
    #
    # @example Using issue attributes
    #   field_id = HrzLib::CustomFieldHelper.create_computed_field(
    #     'Double Estimated Hours',
    #     'float',
    #     'issue',
    #     '(self.estimated_hours || 0) * 2'
    #   )
    #
    # @example Date calculation
    #   field_id = HrzLib::CustomFieldHelper.create_computed_field(
    #     'Days Since Created',
    #     'int',
    #     'issue',
    #     '(Date.today - self.created_on.to_date).to_i if self.created_on'
    #   )
    #
    # @example Complex formula with safe navigation
    #   field_id = HrzLib::CustomFieldHelper.create_computed_field(
    #     'VAT Amount',
    #     'float',
    #     'issue',
    #     '(cfs[1].to_f * cfs[2].to_f * 0.19).round(2) if cfs[1] && cfs[2]'
    #   )
    #
    def self.create_computed_field(name, field_format, customized_type, formula, options = {})
      # Check if Computed Custom Field plugin is available
      unless CustomField.new.respond_to?(:formula=)
        Rails.logger.error "HRZ Lib: Computed Custom Field plugin is not installed!"
        Rails.logger.error "HRZ Lib: Install from: https://github.com/annikoff/redmine_plugin_computed_custom_field"
        return nil
      end

      # Validate formula is not empty
      if formula.nil? || formula.strip.empty?
        Rails.logger.error "HRZ Lib: Formula cannot be empty for computed custom field"
        return nil
      end

      # Merge options with computed flag and formula
      computed_options = options.merge(
        is_computed: true,
        formula: formula
      )

      # Use standard create method
      create_custom_field(name, field_format, customized_type, computed_options)
    end  # create_computed_field



    # Validates a formula without creating a field
    #
    # @param formula [String] The formula to validate
    # @param customized_type [String] The type for context (e.g., 'issue')
    #
    # @return [Hash] Hash with :valid (boolean) and :error (string if invalid)
    #
    # @example Validate a formula
    #   result = HrzLib::CustomFieldHelper.validate_formula('cfs[1] * cfs[2]', 'issue')
    #   if result[:valid]
    #     puts "Formula is valid"
    #   else
    #     puts "Error: #{result[:error]}"
    #   end
    #
    def self.validate_formula(formula, customized_type = 'issue')
      begin
        # Check if plugin is available
        unless CustomField.new.respond_to?(:formula=)
          return {
            valid: false,
            error: "Computed Custom Field plugin not installed"
          }
        end

        # Create a temporary field to test formula validation
        klass = case customized_type
                when 'issue' then IssueCustomField
                when 'project' then ProjectCustomField
                when 'user' then UserCustomField
                when 'time_entry' then TimeEntryCustomField
                else CustomField
                end

        temp_field = klass.new(
          name: "temp_validation_#{Time.now.to_i}",
          field_format: 'string',
          formula: formula
        )

        # Validate without saving
        temp_field.valid?

        if temp_field.errors[:formula].any?
          return {
            valid: false,
            error: temp_field.errors[:formula].join(', ')
          }
        else
          return {
            valid: true,
            error: nil
          }
        end

      rescue => e
        return {
          valid: false,
          error: e.message
        }
      end
    end  # validate_formula



    # Gets available fields for use in formulas
    #
    # @param customized_type [String] The type ('issue', 'project', etc.)
    #
    # @return [Hash] Hash with :custom_fields and :attributes arrays
    #
    # @example Get available fields for issue formulas
    #   fields = HrzLib::CustomFieldHelper.get_formula_fields('issue')
    #   puts "Custom Fields:"
    #   fields[:custom_fields].each { |cf| puts "  cfs[#{cf[:id]}] - #{cf[:name]}" }
    #   puts "Attributes:"
    #   fields[:attributes].each { |attr| puts "  self.#{attr}" }
    #
    def self.get_formula_fields(customized_type)
      begin
        # Get all custom fields for this type
        klass = case customized_type
                when 'issue' then IssueCustomField
                when 'project' then ProjectCustomField
                when 'user' then UserCustomField
                when 'time_entry' then TimeEntryCustomField
                else CustomField
                end

        custom_fields = klass.all.map do |cf|
          {
            id: cf.id,
            name: cf.name,
            field_format: cf.field_format,
            usage: "cfs[#{cf.id}]"
          }
        end

        # Get available model attributes
        model_attributes = case customized_type
                          when 'issue'
                            %w[id subject description status_id tracker_id priority_id
                               assigned_to_id author_id created_on updated_on start_date
                               due_date estimated_hours done_ratio project_id parent_id]
                          when 'project'
                            %w[id name identifier description status created_on updated_on
                               parent_id is_public]
                          when 'user'
                            %w[id login firstname lastname mail admin created_on updated_on
                               last_login_on]
                          when 'time_entry'
                            %w[id hours comments spent_on created_on updated_on user_id
                               activity_id issue_id project_id]
                          else
                            []
                          end

        {
          custom_fields: custom_fields,
          attributes: model_attributes.map { |attr| {name: attr, usage: "self.#{attr}"} }
        }

      rescue => e
        Rails.logger.error "HRZ Lib: Error getting formula fields: #{e.message}"
        {custom_fields: [], attributes: []}
      end
    end  # get_formula_fields


  end  # module CustomFieldHelper
end  # module HrzLib
