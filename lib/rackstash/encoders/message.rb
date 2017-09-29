# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/encoders/helpers/message'

module Rackstash
  module Encoders
    # The Message encoder only returns the message of log event. All other
    # fields and tags are ignored.
    #
    # This encoder is useful in environments where the added fields are not
    # required, mostly during development where debug logs are directly consumed
    # by humans
    class Message
      include Rackstash::Encoders::Helpers::Message

      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the `"message"` field of the event
      def encode(event)
        normalize_message(event)

        event[FIELD_MESSAGE]
      end
    end
  end
end
