# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/encoder'
require 'rackstash/encoder/helper/message'

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
      include Rackstash::Encoder::Helper::Message
      include Rackstash::Encoder::Helper::Timestamp

      # @param tagged [Array<#to_s>] An array of field names whose values are
      #   added in front of each message line on encode
      def initialize(tagged: [])
        @tagged_fields = Array(tagged).map(&:to_s)
      end

      # Return the formatted message of the given event.
      #
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the formatted message of the event
      def encode(event)
        normalize_message(event)
        message = event[FIELD_MESSAGE]

        unless message.empty?
          tags = @tagged_fields.map { |key|
            normalize_timestamp(event, key)
            format_tag event[key]
          }.compact.join
          message = message.gsub(/^/) { tags } unless tags.empty?
        end

        message
      end

      private

      def format_tag(value)
        case value
        when nil
          nil
        when ::Array
          "[#{value.map(&:to_s).join(',')}] "
        else
          "[#{value}] "
        end
      end
    end

    register Message, :message
  end
end
