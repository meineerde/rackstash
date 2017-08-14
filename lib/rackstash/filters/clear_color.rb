# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filters
    # Remove all ANSI color codes from the `"message"` field of the given event
    # `Hash`.
    class ClearColor
      # a regular expression matching ANSI color codes
      COLOR_REGEX = /\e\[[0-9;]*m/.freeze

      # Remove all ANSI color codes from the `"message"` field. The field can
      # either contain a single String or {Message} or an Array of those. If
      # there is no message, we return the event unchanged.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with all ANSI color codes removed from
      #   messages
      def call(event)
        message = event[FIELD_MESSAGE]
        case message
        when Array
          message.map! { |msg|
            msg.gsub(COLOR_REGEX, EMPTY_STRING)
          }
        when String, Message
          event[FIELD_MESSAGE] = message.gsub(COLOR_REGEX, EMPTY_STRING)
        end

        event
      end
    end
  end
end
