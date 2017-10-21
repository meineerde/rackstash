# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'thread'

require 'rackstash/adapter/base_adapter'

module Rackstash
  module Adapter
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
    # different adapter to ensure consistent logs. Suitable adapters for this
    # use-case include {Rackstash::Adapter::File} or
    # {Rackstash::Adapter::TCP}.
    class IO < BaseAdapter
      # This module is by default included into all objects passed to
      # {Adapter::IO#initialize}. It allows to synchronize all write accesses
      # against this object, even when writing to the same object from multiple
      # adapters concurrently.
      #
      # This e.g. allows multiple Loggers in the same process to write to
      # `STDERR` concurrently without risking any overlapping log lines.
      module RackstashLock
        # Initialize the Mutex to synchronize any accesses of a Rackstash
        # adapter to the extended IO object. This method needs to be called at
        # least once on an IO object after {RackstashLock} was included into it.
        #
        # @return [nil]
        def init_for_rackstash
          @lock_for_rackstash ||= Mutex.new
          nil
        end

        # @yield Obtains a lock on the IO object, runs the block, and releases
        #   the lock when the block completes.
        # @return [Object] the return value of the block
        def synchronize_for_rackstash
          @lock_for_rackstash.synchronize do
            yield
          end
        end
      end

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

        io.extend(RackstashLock) unless io.respond_to?(:synchronize_for_rackstash)
        io.init_for_rackstash if io.respond_to?(:init_for_rackstash)
        @io = io
        @flush_immediately = !!flush_immediately
      end

      # Write a single log line with a trailing newline character to the IO
      # object.
      #
      # @param log [#to_s] the encoded log event
      # @return [nil]
      def write_single(log)
        line = normalize_line(log)
        return if line.empty?

        @io.synchronize_for_rackstash do
          @io.write line
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
        @io.synchronize_for_rackstash do
          @io.close
        end
        nil
      end
    end
  end
end
