# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'logger'

require 'rackstash/adapter/adapter'

module Rackstash
  module Adapter
    # The Logger adapter can be used to write formatted logs to an existing
    # logger. This is especially useful with libraries exposing a
    # logger-compatible interface for an external protocol. Example of such
    # loggers include Ruby's `Syslog::Logger` class, a `Loglier` logger to log
    # to Loggly or a fluentd logger.
    #
    # The only expectation to the passed logger instance is that it responds to
    # the `add` method with the same semantics as the `Logger` class in Ruby's
    # standard library. All logs emitted to the given logger will be emitted
    # with the defined severity (`INFO` by default). Since a log event in
    # Rackstash can contain multiple concatenanted messages, you should make
    # sure to format them properly with {Filters} or a custom encoder if
    # required.
    #
    # While most loggers expect Strings as arguments to their `add` method, some
    # also work with hashes or similar data structures. Make sure to configure a
    # suitable `encoder` in the responsible {Flow}. By default, we use a JSON
    # encoder.
    #
    # @note When logging to a local file or to an IO object (like `STDOUT` or
    # `STDERR`), you should use the {File} encoder respectively the {IO} encoder
    # instead which usally provide stronger consistency guarantees and are
    # faster.
    class Logger < Adapter
      register_for ::Logger, 'Syslog::Logger'

      # @param logger [#add] A base logger to send log lines to. We only expect
      #   this object to implement an `add` method which behaves similar to the
      #   one of the Ruby standard library `Logger` class.
      # @param severity [Integer, String, Symbol] the severity of the logs
      #   emitted to the base `logger`. It can be specified as either one of the
      #   {SEVERITIES} or a `String` or `Symbol` describing the severity.
      def initialize(logger, severity: INFO)
        if logger.respond_to?(:add)
          @logger = logger
        else
          raise TypeError, "#{logger.inspect} does not look like a logger"
        end

        self.severity = severity
      end

      # @return [Integer] the severity which will be used to add log events to
      #   the base logger.
      def severity
        @severity
      end

      # This attribute sets the severity of the logs emitted to the base logger.
      # It can be specified as either one of the {SEVERITIES} or a `String` or
      # `Symbol` describing the severity (i.e. its name).
      #
      # @param severity [Integer, String, Symbol] the severity of the logs
      #   emitted to the base `logger`. It can be specified as either one of the
      #   {SEVERITIES} or a `String` or `Symbol` describing the severity.
      # @raise [ArgumentError] if no severity could be found for the given
      #   value.
      def severity=(severity)
        @severity = Rackstash.severity(severity)
      end

      # Close the base logger (if supported). The exact behavior is dependent on
      # the given logger.
      #
      # Usually, no further writes are possible after closing. Further attempts
      # to {#write} will usually result in an exception being thrown.
      #
      # @return [nil]
      def close
        @logger.close if @logger.respond_to?(:close)
        nil
      end

      # Reopen the base logger (if supported). The exact behavior is dependent
      # on the given logger.
      #
      # @return [nil]
      def reopen
        @logger.reopen if @logger.respond_to?(:reopen)
        nil
      end

      # Emit a single log line to the base logger with the configured log
      # {#severity}. If the `Encoder` of the responsible {Flow} created a
      # `String` object, we will log it to the logger with a trailing newline
      # removed. Other objects like a `Hash` are passed along unchanged.
      #
      # @param log [#to_s] the encoded log event. Most loggers expect a `String`
      #   here. Be sure to use a compatible encoder in the responsible {Flow}.
      # @return [nil]
      def write_single(log)
        log = log.chomp("\n".freeze) if log.is_a?(String)

        @logger.add(@severity, log)
        nil
      end
    end
  end
end
