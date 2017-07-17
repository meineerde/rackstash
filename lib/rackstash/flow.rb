# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  class Flow
    def initialize(adapter = nil)
      @adapter = adapter
    end
  end
end
