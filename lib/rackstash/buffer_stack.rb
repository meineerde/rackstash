# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'thread'

require 'rackstash/buffer'

module Rackstash
  # A BufferStack controls one or more Buffers. Each {Buffer} is created,
  # referenced by, and accessed via exactly one BufferStack. Each BufferStack
  # is used by exactly one {Logger}. The responsible {Logger} ensures that each
  # BufferStack is only accessed from a single thread.
  class BufferStack
    # @return [Sink] the log sink where the buffers are eventually flushed to
    attr_reader :sink

    def initialize(sink)
      @sink = sink
      @stack = []
      @stack_mutex = Mutex.new
    end

    # Get the current, i.e., latest, top-most, {Buffer} on the internal stack.
    # If no Buffer was pushed yet with {#push}, this will be an implicit
    # non-buffering Buffer and add it to the stack.
    #
    # @return [Buffer]
    def current
      @stack_mutex.synchronize do
        @stack.last || Buffer.new(@sink, buffering: false).tap do |buffer|
          @stack.push buffer
        end
      end
    end

    # Push a new {Buffer} to the internal stack. The new Buffer will buffer
    # messages by default until it is explicitly flushed with {#flush_and_pop}.
    #
    # All new logged messages, and any access to fields and tags will be sent to
    # this new buffer. Previous Buffers will only be visible once the new Buffer
    # is poped from the stack with {#flush_and_pop}.
    #
    # @param buffer_args [Hash<Symbol => Object>] optional arguments for the new
    #   {Buffer}. See {Buffer#initialize} for allowed values.
    # @return [Buffer] the newly created buffer
    def push(**buffer_args)
      buffer = Buffer.new(sink, **buffer_args)
      @stack_mutex.synchronize do
        @stack.push buffer
      end

      buffer
    end

    # Remove the top-most Buffer from the internal stack.
    #
    # If there was a buffer on the stack and it has pending data, it is flushed
    # to the {#sink} before it is returned.
    #
    # @return [nil]
    def flush_and_pop
      buffer = @stack_mutex.synchronize { @stack.pop }
      buffer.flush if buffer
      nil
    end
  end
end
