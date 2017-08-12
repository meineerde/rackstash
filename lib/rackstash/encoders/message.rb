# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Encoders
    # The Message encoder only returns the message of log event. All other
    # fields and tags are ignored.
    #
    # This encoder is useful in environments where the added fields are not
    # required, mostly during development where debug logs are directly consumed
    # by humans
    class Message
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the `"message"` field of the event. Trailing whitespace
      #     will be removed.
      def encode(event)
        event[FIELD_MESSAGE].rstrip
      end
    end
  end
end
