# frozen_string_literal: true
#
# Copyright 2017-2020 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'date'
require 'socket'
require 'time'

require 'rackstash/encoder'
require 'rackstash/encoder/helper/fields_map'
require 'rackstash/encoder/helper/message'
require 'rackstash/utils'

module Rackstash
  module Encoder
    # The Graylog Extended Log Format (GELF) is the native format used by
    # [Graylog](https://www.graylog.org). By formatting Rackstash's log events
    # as GELF, you can directly send thm to a Graylog server for storage and
    # further processing.
    #
    # GELF is based in JSON with some additional restrictions. Please see
    # [the specification](http://docs.graylog.org/en/2.4/pages/gelf.html) for
    # details. The GELF encoder returns the log event as a JSON-encoded `String`
    # without any literal newline characters.
    #
    # To send Rackstash log events to a Graylog server, you can use the
    # {Adapter::GELF} adapter to send the formatted GELF payload to your Graylog
    # server using any of the supported transport protocols.
    #
    # @see http://docs.graylog.org/en/2.4/pages/gelf.html
    class GELF
      include Rackstash::Encoder::Helper::FieldsMap
      include Rackstash::Encoder::Helper::Message
      include Rackstash::Utils

      # The default mapping of GELF fields (the keys) to fields in the final
      # Rackstash event hash (the value). You can overwrite this mapping by
      # setting the `fields` parameter in {#initialize}.
      DEFAULT_FIELDS = {
        host: nil, # local hostname by default
        level: nil, # highest severity of an event message mapped to a syslog level
        short_message: FIELD_MESSAGE,
        # omitted by default
        full_message: nil,

        # The event's timestamp
        timestamp: FIELD_TIMESTAMP
      }.freeze

      # Mapping of Rackstash log severities to the syslog levels used by GELF
      GELF_LEVELS = {
        DEBUG => 7,  # Debug
        INFO => 6,   # Informational
        WARN => 5,   # Notice
        ERROR => 4,  # Warning
        FATAL => 3,  # Error
        UNKNOWN => 1 # Alert – shouldn't be used
      }.freeze

      # @param fields [Hash<Symbol => String, nil>] a mapping of standard fields
      #   in the emitted GELF message (the Hash keys) to their respective source
      #   fields in the passed Rackstash event (the values). By default, we use
      #   the {DEFAULT_FIELDS} mapping which can selectively be overwritten with
      #   this `fields` argument. All fields in the event Hash which are not
      #   mapped to one of the main GELF fields will be added as additional
      #   GELF fields. If the mapped value is `nil`, we do not include the field
      #   or set it with a default value.
      # @param default_severity [Integer] The default log severity. One of the
      #   {SEVERITIES} constants. If the `level` field of the generated GELF
      #   message is not overwritten with another field and we can not determine
      #   a maximum severity from the event's messages, we emit the syslog level
      #   matching this severity in the `level` field of the generated message.
      def initialize(fields: {}, default_severity: UNKNOWN)
        set_fields_mapping(fields, DEFAULT_FIELDS)
        @default_severity = Rackstash.severity(default_severity)
      end

      # Encode the passed event Hash as a JSON string following the GELF
      # specification.
      #
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the GELF-formatted event as a single-line JSON string
      def encode(event)
        gelf = {}

        # > GELF spec version – "1.1"; MUST be set by client library.
        gelf['version'] = '1.1'.freeze

        # > the name of the host, source or application that sent this message;
        # > MUST be set by client library.
        host = extract_field(:host, event) { Socket.gethostname }
        gelf['host'] = utf8(host)

        # > Seconds since UNIX epoch with optional decimal places for
        # > milliseconds; SHOULD be set by client library. Will be set to the
        # > current timestamp (now) by the server if absent.
        timestamp = extract_field(:timestamp, event)
        gelf['timestamp'] = gelf_timestamp(timestamp)

        # > the level equal to the standard syslog levels; optional, default is
        # > `1` (ALERT)
        # The default value of 1 corresponds to {UNKNOWN} in Rackstash.
        level = extract_field(:level, event) {
          GELF_LEVELS.fetch(max_message_severity(event)) {
            GELF_LEVELS[@default_severity]
          }
        }
        gelf['level'] = Integer(level)

        # Since we need the raw messages to find the GELF level above, we only
        # now normalize the message array to a simple String here
        normalize_message(event)

        # > a short descriptive message; MUST be set by client library.
        short_message = extract_field(:short_message, event) { EMPTY_STRING }
        gelf['short_message'] = utf8(short_message)

        # > a long message that can i.e. contain a backtrace; optional.
        #
        # Since the field is optional, we only write this field if there is a
        # value in our event hash
        full_message = extract_field(:full_message, event)
        gelf['full_message'] = utf8(full_message) if full_message

        gelf.merge! additional_fields(event)

        ::JSON.dump(gelf)
      end

      private

      def gelf_timestamp(timestamp)
        time = case timestamp
        when Time, DateTime
          timestamp.to_time
        when Date
          Time.new(timestamp.year, timestamp.month, timestamp.day, 0, 0, 0, 0)
        when String
          Time.iso8601(timestamp) rescue Time.now.utc
        when Integer, Float
          timestamp
        else
          Time.now.utc
        end

        time.to_f
      end

      def max_message_severity(event)
        messages = event[FIELD_MESSAGE]
        return @default_severity unless messages.is_a?(Array)

        max_severity = nil
        messages.each do |message|
          next unless message.respond_to?(:severity)
          severity = message.severity

          next if severity >= UNKNOWN
          next if max_severity && severity < max_severity

          max_severity = severity
        end

        max_severity || @default_severity
      end

      def additional_fields(event)
        additional_fields = {}

        event.each_pair do |key, value|
          # "_id" is reserved, so use "__id"
          key = '_id'.freeze if key == 'id'.freeze
          add_additional_field(additional_fields, "_#{key}", value)
        end
        additional_fields
      end

      def add_additional_field(result, key, value)
        case value
        when ::Hash
          value.each_pair do |hash_key, hash_value|
            add_additional_field(result, "#{key}.#{hash_key}", hash_value)
          end
        when ::Array
          value.each_with_index do |array_value, index|
            add_additional_field(result, "#{key}.#{index}", array_value)
          end
        when ::Time, ::DateTime
          value = value.to_time.getutc
          result[sanitize(key)] = value.iso8601(ISO8601_PRECISION)
        when ::Date
          result[sanitize(key)] = value.iso8601
        else
          result[sanitize(key)] = value
        end
      end

      def sanitize(key)
        key.gsub(/[^\w\.\-]/, '_'.freeze)
      end
    end

    register GELF, :gelf
  end
end
