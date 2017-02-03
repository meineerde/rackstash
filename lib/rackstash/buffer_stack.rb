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
    # @return [Sink] the log sink where the buffers are eventually flushed to
    attr_reader :sink

    def initialize(sink)
      @sink = sink
    end

    # TODO: this is only a spike for now
    def with_buffer
      yield Buffer.new(@sink)
    end
  end
end
