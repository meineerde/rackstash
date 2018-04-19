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
        # Before any filters, only the `"@timestamp"` field contains a `Time`
        # object denoting the timestamp of the log event. To represent this
        # timestamp in logs, it is formatted as an ISO 8601 string. The
        # timestamp will always be changed into UTC.
        #
        # @param event [Hash] a log event Hash
        # @param field [String] the name of the timestamp field in the event
        #   hash. By default, we use the `"@timestamp"` field.
        # @param force [Bool] set to `true` to use the current time if the
        #   existing timestamp could not be interpreted as a timestamp
        # @return [Hash] the given event with the `field` key set as an ISO 8601
        #   formatted time string.
        def normalize_timestamp(event, field = FIELD_TIMESTAMP, force: false) #:doc:
          time = normalized_time(event[field])
          time ||= Time.now.utc if force

          event[field] = time.iso8601(ISO8601_PRECISION) if time

          event
        end

        # @param time [Time, DateTime, Date, Integer, Float]
        # @return [Time, nil] a `Time` object on UTC timezone if the given
        #   `time` could be normalized as such or `nil` if the value does not
        #   describe a timestamp
        def normalized_time(time) #:doc:
          case time
          when ::Time, ::DateTime
            time = time.to_time
            time.utc? ? time : time.getutc
          when ::Date
            ::Time.new(time.year, time.month, time.day, 0, 0, 0, 0).utc
          end
        end
      end
    end
  end
end
