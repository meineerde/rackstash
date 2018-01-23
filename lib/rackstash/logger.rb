# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'concurrent'

require 'rackstash/buffer_stack'
require 'rackstash/formatter'
require 'rackstash/message'
require 'rackstash/flows'

module Rackstash
  # The Logger is the main entry point for Rackstash. It provides an interface
  # very similar to the Logger class in Ruby's Standard Library but extends it
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

    # @return [Flows] the list of defined {Flow} objects which are responsible
    #   for transforming, encoding, and persisting the log events.
    attr_reader :flows

    # Create a new Logger instance.
    #
    # We mostly follow the common interface of Ruby's core Logger class with the
    # exception that you can give one or more flows to write logs to. Each
    # {Flow} is responsible to write a log event (e.g. to a file, STDOUT, a TCP
    # socket, ...). Each log event is written to all defined {#flows}.
    #
    # When giving the flows here, you can given them in one of varous
    # representations, all of which we will transform into an actual {Flow}:
    #
    # * A {Rackstash::Flow} object. For the most control over the flow, you can
    #   create the {Flow} object on your own and pass it here
    # * A {Rackstash::Adapter::Adapter}. When passing an adapter, we will
    #   create a new {Flow} from this adapter, using its default encoder and
    #   without any defined filters.
    # * An log device from which we can create an adapter. In this case, we
    #   first attempt to build an adapter from it using {Rackstash::Adapter.[]}.
    #   After that, we use it to create a {Flow} as above.
    #
    # When passing a block to this initializer, we will yield the last created
    # flow object to it. If you pass multiple log devices / adapters / flows,
    # only the last one will be yielded. If the block doesn't expect an argument,
    # we run the block in the instance scope of the flow.
    #
    # The following three example to create a custom Logger are thus equivalent:
    #
    #     logger = Rackstash::Logger.new(STDOUT) do
    #       encoder Rackstash::Encoder::Message.new
    #     end
    #
    #     logger = Rackstash::Logger.new(Rackstash::Adapter::IO.new(STDOUT)) do
    #       encoder Rackstash::Encoder::Message.new
    #     end
    #
    #     adapter = Rackstash::Adapter::IO.new(STDOUT)
    #     flow = Rackstash::Flows.new(adapter) do
    #       encoder Rackstash::Encoder::Message.new
    #     end
    #     logger = Rackstash::Logger.new(flow)
    #
    # To create a simple Logger which logs to `STDOUT` using the default JSON
    # format, you can just use
    #
    #     logger = Rackstash::Logger.new(STDOUT)
    #
    # @param flows [Array<Flow, Object>, Flow, Adapter::Adapter, Object]
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
    # @yieldparam flow [Rackstash::Flow] if the given block accepts an argument,
    #   we yield the last {Flow} as a parameter. Without an expected argument,
    #   the block is directly executed in the context of the last {Flow}.
    def initialize(*flows, level: DEBUG, progname: PROGNAME, formatter: Formatter.new, &block)
      @buffer_stack = Concurrent::ThreadLocalVar.new

      @flows = Rackstash::Flows.new(*flows)
      self.level = level
      self.progname = progname
      self.formatter = formatter

      if block_given? && (flow = @flows.last)
        if block.arity == 0
          flow.instance_eval(&block)
        else
          yield flow
        end
      end
    end

    # Add a message to the current {Buffer} without any further formatting. If
    # the current buffer is bufering, the message will just be added. Else,
    # it will be flushed to the configured {#flows} directly.
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

    # (see Flows#close)
    def close
      @flows.close
    end

    # Set the base log level as either one of the {SEVERITIES} or a
    # String/Symbol describing the level. When logging a message, it will only
    # be added if its log level is at or above the base level defined here
    #
    # @param severity [Integer, String, Symbol] one of the {SEVERITIES} or its
    #   name
    def level=(severity)
      @level = Rackstash.severity(severity)
    end

    # (see Buffer#fields)
    def fields
      buffer.fields
    end

    # (see Flows#reopen)
    def reopen
      @flows.reopen
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
    #   constants.
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
        buffer.add_fields(msg)
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
    alias add_error add_exception

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
    # By using the `begin ... ensure` block, you can enforce that the buffer is
    # actually poped and flushed after the execution leaves your environment,
    # even if an Exception is raised. If you omit to pop the Buffer from the
    # stack, weird things can happen and your logs will probably end up not
    # being consistent or not even flushed at all.
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
      @buffer_stack.value ||= BufferStack.new(@flows)
    end

    def buffer
      buffer_stack.current
    end
  end
end
