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
      @stack = []
    end

    # Get the current, i.e., latest, top-most, {Buffer} on the internal stack.
    # If no Buffer was pushed yet with {#push}, this will be an implicit
    # non-buffering Buffer and add it to the stack.
    #
    # @return [Buffer]
    def current
      @stack.last || Buffer.new(@sink, buffering: false).tap do |buffer|
        @stack.push buffer
      end
    end
  end
end
