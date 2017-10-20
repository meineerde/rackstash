# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Encoder
    # The Raw encoder passes along the raw unformatted event hash. It still
    # contains an `Array` of {Message} objects in the `"message"` key and a
    # `Time` object in the `"@timestamp"` key.
    #
    # When expecting a Hash in an adapter, usually it's more useful to use the
    # {Rackstash::Encoder::Hash} encoder instead.
    class Raw
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [Hash] the passed `event`
      def encode(event)
        event
      end
    end
  end
end
