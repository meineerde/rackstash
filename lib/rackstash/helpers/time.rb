# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Helpers
    module Time
      protected

      if defined?(Process::CLOCK_MONOTONIC)
        # Get the current timestamp as a numeric value. If supported by the
        # current platform, we use a monitonic clock.
        #
        # @return [Float] the current timestamp
        def clock_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      else
        # Get the current timestamp as a numeric value
        #
        # @return [Float] the current timestamp
        def clock_time
          ::Time.now.to_f
        end
      end
    end
  end
end
