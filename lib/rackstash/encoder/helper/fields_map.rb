# frozen_string_literal: true
#
# Copyright 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/helpers/utf8'

module Rackstash
  module Encoder
    module Helper
      # Some useful helper methods for {Rackstash::Encoder}s which help in
      # normalizing and handling the message list in the event Hash.
      module FieldsMap
        include Rackstash::Helpers::UTF8

        private

        def set_fields_mapping(fields, default = {})
          @fields_map ||= {}
          default.each do |key, value|
            if fields.key?(key)
              @fields_map[key] = utf8_encode(fields[key])
            else
              # Preserve existing mappings which might have been set by a
              # previous call to {#set_fields_mapping}
              @fields_map[key] ||= utf8_encode(value)
            end
          end
        end

        def extract_field(name, event)
          field_name = field(name)

          field = event.delete(field_name) if field_name
          field = yield(field_name) if field.nil? && block_given?
          field
        end

        def field(name)
          @fields_map[name]
        end
      end
    end
  end
end
