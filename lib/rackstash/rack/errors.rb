# frozen_string_literal: true
# Copyright 2016 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Rack
    # Provide an error stream to Rack applications which logs to a
    # {Rackstash::Logger} instance.
    #
    # According to the [Rack SPEC](http://www.rubydoc.info/github/rack/rack/file/SPEC#The_Error_Stream),
    # the error stream in `env['rack.errors']` must coform to the following
    # interface:
    #
    # > The error stream must respond to `puts`, `write` and `flush`.
    # >
    # > * `puts` must be called with a single argument that responds to `to_s`.
    # > * `write` must be called with a single argument that is a `String`.
    # > * `flush` must be called without arguments and must be called in order
    # >   to make the error appear for sure.
    # > * `close` must never be called on the error stream.
    class Errors
      # @return [Rackstash::Logger]
      attr_reader :logger

      # @param logger [Rackstash::Logger] a {Logger} instance to write error
      #   logs to
      def initialize(logger)
        @logger = logger
      end

      # Close the {logger} and all of its adapters
      # @return [void]
      def close
        @logger.close
      end

      # Log a formatted error message to the current buffer of the `logger`. We
      # will format the given message and log it with an `UNKNOWN` severity to
      # the current buffer. Usually, the logger's formatter adds a trailing
      # newline to the message.
      #
      # @param msg [#to_s] a message to write to the error stream
      # @return [String] the given `msg` as a String
      def puts(msg)
        msg = msg.to_s
        @logger.unknown(msg)
        msg
      end

      # Log a raw and unformatted error message to the current buffer of the
      # `logger`. It will be logged as an unformatted {Message} without any
      # aded newline characters.
      #
      # @param msg [String] a raw message to write to the error stream
      # @return [String] the given `msg`
      def write(msg)
        @logger << msg
        msg
      end

      # This method does nothing. It is only provided to satisfy the
      # requirements of the error stream interface. The {Logger} (resp. its
      # adapters) are responsible to flush their buffers on their own as
      # suitable or required.
      def flush
        # no-op
      end
    end
  end
end
