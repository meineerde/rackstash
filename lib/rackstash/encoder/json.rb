# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'json'

require 'rackstash/encoder/helper/message'
require 'rackstash/encoder/helper/timestamp'

module Rackstash
  module Encoder
    # The JSON encoder formats the log event as a single-line JSON string. The
    # resulting JSON string contains all data exposed by the buffer.
    #
    # Most adapters default to use this encoder.
    class JSON
      include Rackstash::Encoder::Helper::Message
      include Rackstash::Encoder::Helper::Timestamp

      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the event as a single-line JSON string
      def encode(event)
        normalize_message(event)
        normalize_timestamp(event)

        ::JSON.dump(event)
      end
    end
  end
end
