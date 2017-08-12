# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'concurrent'

require 'rackstash/buffer_stack'
require 'rackstash/formatter'
require 'rackstash/message'
require 'rackstash/sink'

module Rackstash
  # The Logger is the main entry point for Rackstash. It provides an interface
  # very similar to the Logger class in Ruby's Stamdard Library but extends it
  # with facilities for structured logging.
  class Logger
    # Logging formatter, a `Proc`-like object which take four arguments and
    # returns the formatted message. The arguments are:
    #
    # * `severity` - The severity of the log message as a String.
    # * `time` - A Time instance representing when the message was logged.
    # * `progname` - The progname passed to the logger method (or the default
    #   {#progname}).
    # * `msg` - The `Object` the user passed to the log message; not necessarily
    #   a String.
    #
    # The formatter should return a String. When no formatter is set, an
    # instance of {Formatter} is used.
    #
    # @return [#call] the log formatter for each individual buffered line
    attr_accessor :formatter

    # @return [Integer] a numeric log level. Normally you'd use one of the
    #   {SEVERITIES} constants, i.e., an integer between 0 and 5. We will only
    #   log messages with a severity above the configured level.
    attr_reader :level

    # @return [String] the logger's progname, used as the default for log
    #   messages if none is passed to {#add} and passed to the {#formatter}.
    #   By default we use {PROGNAME}.
    attr_accessor :progname

    # @return [Sink] the log {Sink} which flushes a {Buffer} to one or more
    #   external log targets like a file, a socket, ...
    attr_reader :sink

    # @param flows [Array<Flow, Object>, Flow, Adapters::Adapter, Object]
    #   an array of {Flow}s or a single {Flow}, respectivly object which can be
    #   used as a {Flow}'s adapter. See {Flow#initialize}.
    # @param level [Integer] a numeric log level. Normally you'd use one of the
    #   {SEVERITIES} constants, i.e., an integer between 0 and 5. We will only
    #   log messages with a severity above the configured level.
    # @param progname [String] the logger's progname, used as the default for
    #   log messages if none is passed to {#add} and passed to the {#formatter}.
    #   By default we use {PROGNAME}.
    # @param formatter [#call] the log formatter for each individual buffered
    #   line. See {#formatter} for details.
    def initialize(flows, level: DEBUG, progname: PROGNAME, formatter: Formatter.new)
      @buffer_stack = Concurrent::ThreadLocalVar.new

      @sink = Rackstash::Sink.new(flows)
      self.level = level
      self.progname = progname
      self.formatter = formatter
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

    # Retrieve a stored value from a given `key` in the current Buffer's fields.
    # This is strictly equivalent to calling `logger.fields[key]`.
    #
    # @param (see Fields::Hash#[])
    # @return (see Fields::Hash#[])
    def [](key)
      buffer.fields[key]
    end

    # Set the value of a key in the current Buffer's fields to the supplied
    # value. You can set nested hashes and arrays here. The hash keys will be
    # normalized as strings.
    # This is strictly equivalent to calling `logger.fields[key] = value`.
    #
    # @param (see Fields::Hash#[]=)
    # @raise [ArgumentError] if you attempt to set one of the forbidden fields,
    #   namely any of {Buffer::FORBIDDEN_FIELDS}
    # @return (see Fields::Hash#[]=)
    def []=(key, value)
      buffer.fields[key] = value
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

    # (see Sink#close)
    def close
      @sink.close
    end

    # (see Sink#default_fields)
    def default_fields
      @sink.default_fields
    end

    # (see Sink#default_fields=)
    def default_fields=(fields)
      @sink.default_fields = fields
    end

    # (see Sink#default_tags)
    def default_tags
      @sink.default_tags
    end

    # (see Sink#default_tags=)
    def default_tags=(tags)
      @sink.default_tags = tags
    end

    # (see Buffer#fields)
    def fields
      buffer.fields
    end

    # (see Sink#flows)
    # @!attribute [r] flows
    def flows
      @sink.flows
    end

    # (see Sink#reopen)
    def reopen
      @sink.reopen
    end

    # (see Buffer#tag)
    def tag(*new_tags, scope: nil)
      buffer.tag(*new_tags, scope: scope)
    end

    # (see Buffer#tags)
    def tags
      buffer.tags
    end

    # (see Buffer#timestamp)
    def timestamp(time = nil)
      buffer.timestamp(time)
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
    # @param msg [#to_s, ::Hash, Exception, nil] The log message. If unset, we
    #   try, to use the return value of the optional block. If we get a `String`
    #   or `Exception`, we log a new {Message}. If it's a Hash, we deep_merge it
    #   into the current buffer's fields instead.
    # @param progname [String, nil] The program name. Can be omitted. It's
    #   treated as a message if no `msg` and `block` are given.
    # @yield If `message` is `nil`, we yield to the block to get a message
    #   string.
    # @return [Message, ::Hash, nil] The merged Hash, or the resolved {Message}
    #   or `nil` if nothing was logged
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

      case msg
      when Hash, Rackstash::Fields::Hash
        buffer.fields.deep_merge!(msg)
        msg
      else
        time = Time.now.utc.freeze
        buffer.add_message Message.new(
          formatter.call(Rackstash.severity_label(severity), time, progname, msg),
          time: time,
          progname: progname,
          severity: severity
        )
      end
    end
    alias log add

    # (see Buffer#add_exception)
    def add_exception(exception, force: true)
      buffer.add_exception(exception, force: force)
    end

    # Create a new {Buffer} and put it on the {BufferStack} for the current
    # Thread. Until it is poped again with {#pop_buffer}, all newly logged
    # messages and any access to fields or tags will be sent to this new Buffer.
    # Previous Buffers will only be visible after it was poped. You should make
    # sure that the Buffer is only ever used by the calling Thread to retain the
    # thread-safety guarantees of Rackstash.
    #
    # Most of the time, you should use {#with_buffer} instead to ensure that the
    # Buffer is reliably removed again when the execution leaves the block.
    # The only sensible use of the manual buffer management is when you need
    # to flush the Buffer outside of its active scope after it was poped.
    #
    # When using this method, it is crucial that you manually pop and flush the
    # buffer in all cases. This can look like this:
    #
    #     logger.push_buffer(buffering: true)
    #     begin
    #       logger.fields['key'] = 'value'
    #       logger.info 'performing some work...'
    #     ensure
    #       buffer = logger.pop_buffer
    #       buffer.flush if buffer
    #     end
    #
    # By using the `begin ... ensure` block, you can enfore that the buffer is
    # actually poped and flushed afte the execution leaves your environment,
    # even in an Exception is raised. If you omit to pop the Buffer from the
    # stack, weird things can happen and your logs will probably end up not
    # being consistent or even flushed.
    #
    # @see #pop_buffer
    #
    # @param buffer_args [Hash<Symbol => Object>] optional arguments for the new
    #   {Buffer}. See {Buffer#initialize} for allowed values.
    # @return [Buffer] the newly pushed {Buffer} instance
    def push_buffer(buffer_args = {})
      buffer_stack.push(buffer_args)
    end

    # Remove a previously pushed {Buffer} from the {BufferStack} for the current
    # Thread.
    #
    # You should only call this method after having called {#push_buffer} before
    # in the very same Thread and only exactly as many times as you have called
    # {#push_buffer} in that Thread. If you call this method too many times or
    # without first calling {#push_buffer}, it will destroy the consistency of
    # BufferStack causing undefined (i.e. weird) behavior.
    #
    # Since the Buffer is not flushed before returning, it is possible to still
    # modify the buffer before eventually flushing it on your own.
    #
    # Should it happen that there is no Buffer on the {BufferStack} (which can
    # only happen if the code execution was non-linear and stepped outside the
    # block scope), we return `nil` and not change the BufferStack.
    #
    # @note In contrast to {#with_buffer}, the poped Buffer is not flushed
    #   automatically. You *MUST* call `buffer.flush` yourself to write the
    #   buffered log data to the log adapter(s).
    # @see #push_buffer
    #
    # @return [Buffer, nil] the removed {Buffer} from the current Thread's
    #   {BufferStack} or `nil` if no {Buffer} could be found on the stack.
    def pop_buffer
      buffer_stack.pop
    end

    # Create a new buffering {Buffer} and put in on the {BufferStack} for the
    # current Thread. For the duration of the block, all new logged messages
    # and any access to fields and tags will be sent to this new buffer.
    # Previous buffers will only be visible after the execution left the block.
    #
    # Note that the created {Buffer} is only valid for the current Thread. In
    # other Threads, it will neither be used not visible.
    #
    # @param buffer_args [Hash<Symbol => Object>] optional arguments for the new
    #   {Buffer}. See {Buffer#initialize} for allowed values.
    # @yield During the duration of the block, all logged messages, fields and
    #   tags are set on the new buffer. After the block returns, the {Buffer} is
    #   removed from the {BufferStack} again and is always flushed
    #   automatically.
    # @return [Object] the return value of the block
    def with_buffer(buffer_args = {})
      raise ArgumentError, 'block required' unless block_given?

      buffer_stack.push(buffer_args)
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
  end
end
