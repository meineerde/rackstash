# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Encoders
    # The Raw encoder formats the log event as a raw `Hash` containing all data
    # exposed by the buffer. This can be used by special log targets which are
    # designed to handle hashes as opposed to formatted strings.
    class Raw
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [Hash] the passed `event`
      def encode(event)
        event
      end
    end
  end
end
