# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Encoder
    module Helper
      # Some useful helper methods for {Rackstash::Encoder}s which help in
      # normalizing and handling the message list in the event Hash.
      module Message
        private

        # Normalize the `"message"` field of the given log event Hash.
        #
        # @param event [Hash] a log event Hash
        # @param field [String] the name of the field  to normalize in the
        #   `event`
        # @param force [Boolean] set to `true` to always set the `field` to a
        #   normalized value, even if it was empty or missing before
        # @return [Hash] the given event with the normalized message
        def normalize_message(event, field = FIELD_MESSAGE, force: false) #:doc:
          message = event[field]
          return event if message.nil? && !force

          event[field] = normalized_message(message)
          event
        end

        # Normalize various possible values in the `"message"` field of an event
        # Hash into a single String.
        #
        # While the filters still had access to the array of {Message} objects
        # for filtering, we now concatenate the raw message objects as a single
        # string to get the final message which is set on the `event["message"]`
        # key.
        #
        # Usually, the individual messages already contain trailing newline
        # characters. By default, these are added by the formatter of the
        # {Logger} when the message is originally logged. As such, we
        # concatenate all messages without an added separators.
        #
        # @param message [Object] the message(s) to normalize
        # @return [String] the normalized event message as a single String
        def normalized_message(message) #:doc:
          case message
          when Array
            message.map(&:to_s).join
          else
            message.to_s
          end
        end
      end
    end
  end
end
