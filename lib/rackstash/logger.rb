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
        case severity.to_s.downcase
        when 'debug'.freeze
          @level = DEBUG
        when 'info'.freeze
          @level = INFO
        when 'warn'.freeze
          @level = WARN
        when 'error'.freeze
          @level = ERROR
        when 'fatal'.freeze
          @level = FATAL
        when 'unknown'.freeze
          @level = UNKNOWN
        else
          raise ArgumentError, "invalid log level: #{severity}"
        end
      end
    end

    # Log a `message` at the DEBUG log level.
    #
    # @param message (see #add)
    # @yield (see #add)
    # @return (see #add)
    def debug(message = nil)
      if block_given?
        add(DEBUG, message) { yield }
      else
        add(DEBUG, message)
      end
    end

    # @return [Boolean] `true` if messages on the DEBUG level will be logged
    def debug?
      @level <= DEBUG
    end

    # Log a `message` at the INFO log level.
    #
    # @param message (see #add)
    # @yield (see #add)
    # @return (see #add)
    def info(message = nil)
      if block_given?
        add(INFO, message) { yield }
      else
        add(INFO, message)
      end
    end

    # @return [Boolean] `true` if messages on the INFO level will be logged
    def info?
      @level <= INFO
    end

    # Log a `message` at the WARN log level.
    #
    # @param message (see #add)
    # @yield (see #add)
    # @return (see #add)
    def warn(message = nil)
      if block_given?
        add(WARN, message) { yield }
      else
        add(WARN, message)
      end
    end

    # @return [Boolean] `true` if messages on the WARN level will be logged
    def warn?
      @level <= WARN
    end

    # Log a `message` at the ERROR log level.
    #
    # @param message (see #add)
    # @yield (see #add)
    # @return (see #add)
    def error(message = nil)
      if block_given?
        add(ERROR, message) { yield }
      else
        add(ERROR, message)
      end
    end

    # @return [Boolean] `true` if messages on the ERROR level will be logged
    def error?
      @level <= ERROR
    end

    # Log a `message` at the FATAL log level.
    #
    # @param message (see #add)
    # @yield (see #add)
    # @return (see #add)
    def fatal(message = nil)
      if block_given?
        add(FATAL, message) { yield }
      else
        add(FATAL, message)
      end
    end

    # @return [Boolean] `true` if messages on the FATAL level will be logged
    def fatal?
      @level <= FATAL
    end

    # Log a `message` at the UNKNOWN log level.
    #
    # @param message (see #add)
    # @yield (see #add)
    # @return (see #add)
    def unknown(message = nil)
      if block_given?
        add(UNKNOWN, message) { yield }
      else
        add(UNKNOWN, message)
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
    # @param severity [Integer] The log severity. One of {DEBUG}, {INFO},
    #   {WARN}, {ERROR}, {FATAL}, or {UNKNOWN}.
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

      buffer.add_message Message.new(
        msg,
        time: Time.now.utc.freeze,
        progname: progname,
        severity: severity,
        formatter: formatter
      )

      msg
    end
    alias :log :add

    private

    def buffer_stack
      @buffer_stack.value ||= BufferStack.new(@sink)
    end

    def buffer
      buffer_stack.current
    end
  end
end
