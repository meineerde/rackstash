# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Encoders
    module Helpers
      # Some useful helper methods for {Encoders} which help in normalizing and
      # handling the message list in the event Hash.
      module Message
        private

        # Normalize the `"message"` field of the given log event Hash.
        #
        # While the filters still had access to the array of {Message} objects
        # for filtering, we now concatenate the raw message objects as a single
        # string to get the final message which is set on the `event["message"]`
        # key.
        #
        # We expect that the single messages already contain trailing newline
        # characters is deemed useful. These are usually added by the formatter
        # of the frontend {Logger}.
        #
        # @param event [Hash] a log event Hash
        # @return [Hash] the given event with the `"message"` key set as a
        #   single string.
        def normalize_message(event) #:doc:
          event[FIELD_MESSAGE] =
            case event[FIELD_MESSAGE]
            when Array
              event[FIELD_MESSAGE].map!(&:to_s).join
            when nil
              ''
            else
              event[FIELD_MESSAGE].to_s
            end
          event
        end
      end
    end
  end
end
