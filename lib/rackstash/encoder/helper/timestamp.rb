# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'date'
require 'time'

module Rackstash
  module Encoder
    module Helper
      # Some useful helper methods for {Rackstash::Encoder}s which help in
      # normalizing and handling timestamps in the event Hash, especially the
      # {FIELD_TIMESTAMP} field.
      module Timestamp
        private

        # Normalize the `"@timestamp"` field of the given log event Hash.
        # Before any filters, only the `"@timestamp"` fueld contains a `Time`
        # object denoting the timestamp of the log event. To represent this
        # timestamp in logs, it is formatted as an ISO 8601 string. The
        # timestamp will always be changed into UTC.
        #
        # @param event [Hash] a log event Hash
        # @param field [String] the name of the timestamp field in the event
        #   hash. By default, we use the `"@timestamp"` field.
        # @return [Hash] the given event with the `field` key set as an ISO 8601
        #   formatted time string.
        def normalize_timestamp(event, field: FIELD_TIMESTAMP) #:doc:
          time = event[field]

          if time.is_a?(Time) || time.is_a?(DateTime)
            time = time.to_time
            time = time.getutc unless time.utc?
            event[field] = time.iso8601(ISO8601_PRECISION).freeze
          end

          event
        end
      end
    end
  end
end
