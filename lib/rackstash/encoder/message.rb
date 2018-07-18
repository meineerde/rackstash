# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'date'
require 'time'

require 'rackstash/encoder'
require 'rackstash/encoder/helper/message'
require 'rackstash/helpers/utf8'

module Rackstash
  module Encoder
    # The Message encoder only returns the formatted message of log event. All
    # other fields and tags are ignored. This encoder is useful in environments
    # where the added fields are not required, mostly during development where
    # (debug) logs are directly consumed by humans.
    #
    # If any `tagged` fields are given in the initializer, we gather their
    # values from the event and prefix them to each line in the message if the
    # current event contains a value at the given field names.
    #
    #     encoder = Rackstash::Encoder::Message.new(tagged: ['tags', 'remote_ip'])
    #
    #     event = {
    #       'remote_ip' => '127.0.0.1',
    #       'tags' => ['foo', 123],
    #       'message' => ["Hello\n", "World\n"],
    #       'key' => 'value'
    #     }
    #     encoder.encode(event)
    #     # Logs "[foo,123] [127.0.0.1] Hello\n[foo,123] [127.0.0.1] World\n"
    class Message
      include Rackstash::Helpers::UTF8
      include Rackstash::Encoder::Helper::Message
      include Rackstash::Encoder::Helper::Timestamp

      attr_reader :tagged

      # @param tagged [Array<#to_s>] An array of field names whose values are
      #   added in front of each message line on {#encode}
      def initialize(tagged: [])
        @tagged = Array(tagged).map { |tag| utf8_encode(tag) }.freeze
      end

      # Return the formatted message of the given event.
      #
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the formatted message of the event
      def encode(event)
        message = event[FIELD_MESSAGE]
        return EMPTY_STRING if message.nil?

        message = normalized_message(message)
        unless message.empty?
          tags = @tagged.map { |key| format_tag event[key] }.join
          message = message.gsub(/^/) { tags } unless tags.empty?
        end

        message
      end

      private

      def format_tag(value)
        return EMPTY_STRING if value.nil?

        "[#{format_tag_value(value)}] "
      end

      def format_tag_value(value)
        case value
        when ::Array
          value.map { |v| format_tag_value(v) }.join(',')
        when ::Hash
          value.map { |k, v| "#{k.to_s}:#{format_tag_value(v)}" }.join(',')
        when ::Time, ::DateTime
          value = value.to_time.getutc
          value.iso8601(ISO8601_PRECISION)
        when ::Date
          value.iso8601(ISO8601_PRECISION)
        else
          value.to_s
        end
      end
    end

    register Message, :message
  end
end
