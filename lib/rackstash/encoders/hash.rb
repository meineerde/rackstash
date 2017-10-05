# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/encoders/helpers/message'
require 'rackstash/encoders/helpers/timestamp'

module Rackstash
  module Encoders
    # The Hash encoder formats the log event as a raw `Hash` containing all data
    # exposed by the buffer. This can be used by special log targets which are
    # designed to handle hashes as opposed to formatted strings.
    class Hash
      include Rackstash::Encoders::Helpers::Message
      include Rackstash::Encoders::Helpers::Timestamp

      # @param event [Hash] a log event as produced by the {Flow}
      # @return [Hash] the normalized event
      def encode(event)
        normalize_message(event)
        normalize_timestamp(event)

        event
      end
    end
  end
end
