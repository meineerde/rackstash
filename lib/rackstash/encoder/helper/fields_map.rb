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
          @fields_map = default.dup
          Hash(fields).each_pair do |key, value|
            @fields_map[key.to_sym] = utf8_encode(value)
          end
        end

        def extract_field(name, event)
          field_name = @fields_map[name]

          field = event.delete(field_name) if field_name
          field = yield(field_name) if field.nil? && block_given?
          field
        end
      end
    end
  end
end
