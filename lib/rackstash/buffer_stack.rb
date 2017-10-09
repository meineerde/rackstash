# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/buffer'

module Rackstash
  # A BufferStack controls one or more Buffers. Each {Buffer} is created,
  # referenced by, and accessed via exactly one BufferStack. Each BufferStack
  # is used by exactly one {Logger}. The responsible {Logger} ensures that each
  # BufferStack is only accessed from a single thread.
  class BufferStack
    # @return [Flows] the list of defined {Flow} objects which are responsible
    #   for transforming, encoding, and persisting the log events.
    attr_reader :flows

    def initialize(flows)
      @flows = flows
      @stack = []
    end

    # Get the current, i.e., latest, top-most, {Buffer} on the internal stack.
    # If no Buffer was pushed yet with {#push}, this will be an implicit
    # non-buffering Buffer and add it to the stack.
    #
    # @return [Buffer]
    def current
      @stack.last || Buffer.new(@flows, buffering: false).tap do |buffer|
        @stack.push buffer
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
    def push(buffer_args = {})
      buffer = Buffer.new(@flows, buffer_args)
      @stack.push buffer

      buffer
    end

    # Remove the top-most {Buffer} from the internal stack without flushing it.
    #
    # @return [Buffer, nil] the poped {Buffer} or `nil` if there was no {Buffer}
    #   to remove.
    def pop
      @stack.pop
    end

    # Flush and remove the top-most {Buffer} from the internal stack.
    #
    # @return [Buffer, nil] the poped and flushed {Buffer} or `nil` if there was
    #   no {Buffer} to remove
    def flush_and_pop
      buffer = @stack.pop
      buffer.flush if buffer
      buffer
    end
  end
end
