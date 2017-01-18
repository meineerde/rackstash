# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/buffer'

module Rackstash
  # A BufferStack controls one or more Buffers. Each {Buffer} is created,
  # referenced by, and accessed via exactly one BufferStack. Each BufferStack
  # is used by exactly one BufferedLogger. The responsible {BufferedLogger}
  # ensures that each BufferStack is only accessed from a single `Thread`.
  class BufferStack
    # TODO: this is only a spike for now
    def with_buffer
      yield Buffer.new
    end
  end
end
