# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/encoders/helpers/timestamp'

module Rackstash
  module Encoders
    # The Lograge encoder formats the log event in the original key-value format
    # of the [lograge gem](https://github.com/roidrage/lograge).
    #
    # The fields of the passed event are serielized to simple `key=value` pairs,
    # separated by a single space each. The following formatting rules apply:
    #
    # * Field names for nested Hashes and Arrays are separated by a dot to form
    #   a unique key name
    # * Arrays are formatted the same as nested hashes, using the value's index
    #   in the array in the field name for each value.
    # * Floats are formatted with 2 decimal digits
    # * Newlines, dots, equals signs or spaces in keys and values are preserved
    #   and not escaped in any way (apart from the `"error"` field, see below).
    #   You might thus want to avoid any whitespace charactes in general and
    #   dots or equals signs in hash keys. You can use filters in your {Flow} to
    #   ensure suitable field names.
    # * The `"message"` and `"error_trace"` fields are never included in the
    #   output.
    # * If there is an error in the event hash, we will generate a quoted string
    #   from the `"error"` and `"error_message"` fields.
    #
    # Given the following event
    #
    #     {
    #       "@timestamp" => Time.utc(2017, 4, 18, 23, 21, 58),
    #       "message" => ["This is ignored"],
    #       "foo" => ["bar", "baz"],
    #       "beep" => {
    #         "pling" => "plong",
    #         "toot" => "chirp"
    #       },
    #       "runtime" => 3.14159
    #     }
    #
    # the encoder will output the following log line:
    #
    #     timestamp=2017-04-18T23:21:58.000000Z foo.0=bar foo.1=baz beep.pling=plong beep.toot=chirp runtime=3.14
    #
    # With an error in the event hash, e.g. like this
    #
    #     {
    #       "@timestamp" => Time.utc(2017, 4, 18, 23, 21, 58),
    #       "message" => ["This is ignored"],
    #       "error" => "RuntimeError",
    #       "error_message" => "Something bad happened",
    #       "error_trace" => "my_lib.rb:5:in `broken_method'\nmy_lib.rb:10:in `<main>'"
    #     }
    #
    # the encoder will output the following log line:
    #
    #     timestamp=2017-04-18T23:21:58.000000Z error='RuntimeError: Something bad happened'
    #
    class Lograge
      include Rackstash::Encoders::Helpers::Timestamp

      SKIP = [
        FIELD_MESSAGE,
        FIELD_ERROR_TRACE
      ].freeze

      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] a log line with formatted key-value pairs
      def encode(event)
        normalize_timestamp(event)

        format_error(event)
        skip_fields(event)

        serialize_hash(event)
      end

      private

      def format_error(event)
        error = event[FIELD_ERROR]
        error_message = event.delete(FIELD_ERROR_MESSAGE)

        event[FIELD_ERROR] =
          if error.nil?
            error_message.nil? ? nil : "'#{error_message}'"
          else
            error_message.nil? ? "'#{error}'" : "'#{error}: #{error_message}'"
          end
      end

      def skip_fields(event)
        SKIP.each do |field|
          event.delete(field)
        end
      end

      def serialize_hash(hash, prefix: nil)
        hash.map { |key, value|
          serialize_pair(key, value, prefix)
        }.compact.join(' '.freeze)
      end

      def serialize_array(array, prefix: nil)
        array.each_with_index.map { |value, index|
          serialize_pair(index.to_s, value, prefix)
        }.compact.join(' '.freeze)
      end

      def serialize_pair(key, value, prefix)
        if prefix
          key = "#{prefix}.#{key}"
        elsif key == FIELD_TIMESTAMP
          # Use 'timestamp' instead of '@timestamp' on the top-level
          key = 'timestamp'
        end

        case value
        when nil
          return
        when Hash
          return if value.empty?
          return serialize_hash(value, prefix: key)
        when Array
          return if value.empty?
          return serialize_array(value, prefix: key)
        when Float
          value = Kernel.format('%.2f'.freeze, value)
        end

        "#{key}=#{value}"
      end
    end
  end
end
