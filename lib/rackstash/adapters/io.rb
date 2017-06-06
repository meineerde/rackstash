# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'thread'

require 'rackstash/adapters/adapter'

module Rackstash
  module Adapters
    # This adapter allows to write logs to an existing `IO` object, e.g.,
    # `STDOUT`, an open file, a `StringIO` object, ...
    #
    # When writing a [12factor](https://12factor.net/logs) app, you can use this
    # adapter to write formatted logs to `STDOUT` of the process to be captured
    # by the environment and eventually sent to a log collector.
    #
    # Concurrent writes to this adapter will be serialized to ensure there are
    # no overlapping writes. You still have to ensure that there are no other
    # writes to the IO object from outside this adapter to ensure there that
    # is no overlapping data visible on the IO object.
    #
    # Note that with some deployment models involving pre-forked application
    # servers, e.g., Unicorn or Puma servers with multiple worker processes, the
    # combined `STDOUT` stream of multiple processes can cause interleaved data
    # when writing large log lines (typically > 4 KB). If you are using such a
    # deployment model and expect large log lines, you should consider using a
    # different adapter to ensure consistent logs.
    #
    # Suitable adapters include:
    #
    # * {Rackstash::Adapters::File} - When writing to a file, we ensure with
    #   explicit file locks that all data is written consistently.
    # * {Rackstash::Adapters::TCP} - With a single TCP connection per adapter
    #   instance, the receiver can handle the log lines separately.
    class IO < Adapter
      register_for ->(o) { o.respond_to?(:write) && o.respond_to?(:close) }

      # @return [Boolean] `true` to ensure that the IO device is flushed after
      #   each {#write} or `false` to never explicitly flush but rely on the IO
      #   object to eventually flush on its own.
      attr_accessor :flush_immediately

      # @param io [#write, #close] an IO object. It must at least respond to
      #   `write` and `close`.
      # @param flush_immediately [Boolean] set to `true` to flush the IO object
      #   after each write.
      def initialize(io, flush_immediately: false)
        unless io.respond_to?(:write) && io.respond_to?(:close)
          raise TypeError, "#{io.inspect} does not look like an IO object"
        end

        @io = io
        @flush_immediately = !!flush_immediately

        @mutex = Mutex.new
      end

      # Write a single log line with a trailing newline character to the IO
      # object.
      #
      # @param log [#to_s] the encoded log event
      # @return [nil]
      def write_single(log)
        @mutex.synchronize do
          @io.write normalize_line(log)
          @io.flush if @flush_immediately
        end
        nil
      end

      # Close the IO object.
      #
      # After closing, no further writes are possible. Further attempts to
      # {#write} will result in an exception being thrown.
      #
      # @return [nil]
      def close
        @mutex.synchronize do
          @io.close
        end
        nil
      end
    end
  end
end
