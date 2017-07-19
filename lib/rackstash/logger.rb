# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'concurrent'
require 'forwardable'

require 'rackstash/buffer_stack'
require 'rackstash/formatter'
require 'rackstash/message'
require 'rackstash/sink'

module Rackstash
  # The Logger is the main entry point for Rackstash. It provides an interface
  # very similar to the Logger class in Ruby's Stamdard Library but extends it
  # with facilities for structured logging.
  class Logger
    extend Forwardable

    # Logging formatter, a `Proc`-like object which take four arguments and
    # returns the formatted message. The arguments are:
    #
    # * `severity` - The Severity of the log message.
    # * `time` - A Time instance representing when the message was logged.
    # * `progname` - The progname configured passed to the logger method.
    # * `msg` - The `Object` the user passed to the log message; not necessarily
    #   a String.
    #
    # The formatter should return a String. When no formatter is set, an
    # instance of {Formatter} is used.
    #
    # @return [#call] the log formatter for each individual buffered line
    attr_accessor :formatter

    # @return [Integer] a numeric log level, normally you'd use one of the
    #   `SEVERITIES` constants, i.e. an integer between 0 and 5.
    attr_reader :level

    # @return [String] the logger's progname, used as the default for log
    #   messages if none is passed to {#add} and passed to the {#formatter}.
    #   By default we use {PROGNAME}.
    attr_accessor :progname

    # @return [Sink] the log {Sink} which flushes a {Buffer} to one or more
    #   external log targets like a file, a socket, ...
    attr_reader :sink

    def initialize(targets)
      @sink = Sink.new(targets)

      @level = DEBUG
      @progname = PROGNAME
      @formatter = Formatter.new

      @buffer_stack = Concurrent::ThreadLocalVar.new
    end

    # Add a message to the current buffer without any further formatting. If
    # the current {Buffer} is bufering, the message will just be added. Else,
    # it will be flushed to the {#sink} directly.
    #
    # @param msg [Object]
    # @return [String] the passed `msg`
    def <<(msg)
      buffer.add_message Message.new(
        msg,
        time: Time.now.utc.freeze,
        progname: @progname,
        severity: UNKNOWN
      )
      msg
    end

    # Set the base log level as either one of the {SEVERITIES} or a
    # String/Symbol describing the level. When logging a message, it will only
    # be added if its log level is at or above the base level defined here
    #
    # @param severity [Integer, String, Symbol] one of the {SEVERITIES} or its
    #   name
    def level=(severity)
      if severity.is_a?(Integer)
        @level = severity
      else
        @level = SEVERITY_NAMES.fetch(severity.to_s.downcase) do
          raise ArgumentError, "invalid log level: #{severity}"
        end
      end
    end

    # (see Buffer#fields)
    def fields
      buffer.fields
    end

    # (see Buffer#tags)
    def tags
      buffer.tags
    end

    # Log a message at the DEBUG log level.
    #
    # @param msg (see #add)
    # @yield (see #add)
    # @return (see #add)
    def debug(msg = nil)
      if block_given?
        add(DEBUG, msg) { yield }
      else
        add(DEBUG, msg)
      end
    end

    # @return [Boolean] `true` if messages on the DEBUG level will be logged
    def debug?
      @level <= DEBUG
    end

    # Log a message at the INFO log level.
    #
    # @param msg (see #add)
    # @yield (see #add)
    # @return (see #add)
    def info(msg = nil)
      if block_given?
        add(INFO, msg) { yield }
      else
        add(INFO, msg)
      end
    end

    # @return [Boolean] `true` if messages on the INFO level will be logged
    def info?
      @level <= INFO
    end

    # Log a message at the WARN log level.
    #
    # @param msg (see #add)
    # @yield (see #add)
    # @return (see #add)
    def warn(msg = nil)
      if block_given?
        add(WARN, msg) { yield }
      else
        add(WARN, msg)
      end
    end

    # @return [Boolean] `true` if messages on the WARN level will be logged
    def warn?
      @level <= WARN
    end

    # Log a message at the ERROR log level.
    #
    # @param msg (see #add)
    # @yield (see #add)
    # @return (see #add)
    def error(msg = nil)
      if block_given?
        add(ERROR, msg) { yield }
      else
        add(ERROR, msg)
      end
    end

    # @return [Boolean] `true` if messages on the ERROR level will be logged
    def error?
      @level <= ERROR
    end

    # Log a message at the FATAL log level.
    #
    # @param msg (see #add)
    # @yield (see #add)
    # @return (see #add)
    def fatal(msg = nil)
      if block_given?
        add(FATAL, msg) { yield }
      else
        add(FATAL, msg)
      end
    end

    # @return [Boolean] `true` if messages on the FATAL level will be logged
    def fatal?
      @level <= FATAL
    end

    # Log a message at the UNKNOWN log level.
    #
    # @param msg (see #add)
    # @yield (see #add)
    # @return (see #add)
    def unknown(msg = nil)
      if block_given?
        add(UNKNOWN, msg) { yield }
      else
        add(UNKNOWN, msg)
      end
    end

    # @return [Boolean] `true` if messages on the UNKNOWN level will be logged
    def unknown?
      @level <= UNKNOWN
    end

    # Log a message if the given severity is high enough. This is the generic
    # logging method. Users will be more inclined to use {#debug}, {#info},
    # {#warn}, {#error}, or {#fatal}.
    #
    # The message will be added to the current log buffer. If we are currently
    # buffering (i.e. if we are inside a {#with_buffer} block), the message is
    # merely added but not flushed to the underlying logger. Else, the message
    # along with any previously defined fields and tags will be flushed to the
    # base logger immediately.
    #
    # @param severity [Integer] The log severity. One of the {SEVERITIES}
    #   consants.
    # @param msg [#to_s, Exception, nil] The log message. A `String` or
    #   `Exception`. If unset, we try to use the return value of the optional
    #   block.
    # @param progname [String, nil] The program name. Can be omitted. It's
    #   treated as a message if no `msg` and `block` are given.
    # @yield If `message` is `nil`, we yield to the block to get a message
    #   string.
    # @return [String] The resolved unformatted message string
    def add(severity, msg = nil, progname = nil)
      severity = severity ? Integer(severity) : UNKNOWN
      return if @level > severity

      progname ||= @progname
      if msg.nil?
        if block_given?
          msg = yield
        else
          msg = progname
          progname = @progname
        end
      end

      time = Time.now.utc.freeze
      formatted_msg = formatter.call(
        severity_label(severity),
        time,
        progname,
        msg
      )
      buffer.add_message Message.new(
        formatted_msg,
        time: time,
        progname: progname,
        severity: severity
      )

      formatted_msg
    end
    alias log add

    # Create a new buffering {Buffer} and puts in on the {BufferStack} for the
    # current Thread. For the duration of the block, all new logged messages
    # and any access to fields and tags will be sent to this new buffer.
    # Previous buffers will only be visible after the execition left the block.
    #
    # @param buffer_args [Hash<Symbol => Object>] optional arguments for the new
    #   {Buffer}. See {Buffer#initialize} for allowed values.
    # @return [Object] the return value of the block
    def with_buffer(**buffer_args)
      raise ArgumentError, 'block required' unless block_given?

      buffer_stack.push(**buffer_args)
      begin
        yield
      ensure
        buffer_stack.flush_and_pop
      end
    end

    private

    def buffer_stack
      @buffer_stack.value ||= BufferStack.new(@sink)
    end

    def buffer
      buffer_stack.current
    end

    def severity_label(severity)
      SEVERITY_LABELS[severity] || SEVERITY_LABELS.last
    end
  end
end
