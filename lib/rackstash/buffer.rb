# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/fields'

module Rackstash
  # The Buffer holds all the data of a single log event. It can hold multiple
  # messages of multiple calls to the log, additional fields holding structured
  # data about the log event, and tags identiying the type of log.
  #
  # Each time, a message is logged or a field or tag is set to a {Logger}, it
  # is set on a Buffer. Each Buffer belongs to exactly one {BufferStack} (and
  # thus in turn to exactly one {Logger}) which creates it and controls its
  # complete life cycle. The data a buffer holds can be exported via a {Sink}
  # and passed on to one or more {Target}s which send the data to an external
  # log receiver.
  #
  # Most methods of the Buffer are directly exposed to the user-accessible
  # {Logger}. The Buffer class itself is considered private and should not be
  # relied on in external code. The {Logger} respectively the {BufferStack}
  # ensures that a single buffer will only be accessed by one thread at a time
  # by exposing a Buffer to each thread as the "current Buffer".
  #
  # Buffers can be buffering or non-buffering. While this doesn't affect the
  # behavior of the Buffer itself, it affects when the Buffer is flushed to a
  # {Sink} and what happens to the data stored in the Buffer after that.
  #
  # Generally, a non-buffering Buffer will be flushed to the sink after each
  # logged message. This thus mostly resembles the way traditional loggers work
  # in Ruby. A buffering Buffer however holds log messages for a longer time,
  # e.g., for the duration of a web request. Only after the request finished
  # all log messages and stored fields for this request will be flushed to the
  # {Sink} as a single log event.
  #
  # While the fields structure of a Buffer is geared towards the format used by
  # Logstash, it can be adaptd in many ways suited for a specific log target.
  #
  # @note The Buffer class is designed to be created and used by its responsible
  #   {BufferStack} object only and is not intended used from multiple Threads
  #   concurrently.
  class Buffer
    # A set of field names which are forbidden from being set as fields. The
    # fields mentioned here are all either statically set or are accessed by
    # specialized accessor methods.
    FORBIDDEN_FIELDS = Set[
      FIELD_MESSAGE,    # filled with #{add_message}
      FIELD_TAGS,       # set with {#tag}
      FIELD_TIMESTAMP,  # an ISO8601 timestamp of the log event
      FIELD_VERSION,    # the version of the schema. Currently "1"
    ].freeze

    # @return [Fields::Hash] the defined fields of the current buffer in a
    #   hash-like structure
    attr_reader :fields

    # @return [Fields::Tags] a tags list containing the defined tags for the
    #   current buffer. It contains frozen strings only.
    attr_reader :tags

    # @return [Sink] the log sink where the buffer is eventually flushed to
    attr_reader :sink

    # @param buffering [Boolean] When set to `true`, this buffer is considered
    #   to be buffering data. When buffering, logged messages will not be
    #   flushed immediately but only with an explicit call to {#flush}.
    # @param allow_empty [Boolean] When set to `true` the data in this buffer
    #   will be flushed to the sink, even if no messages were logged but there
    #   were just added fields or tags. If this is `false` and there were no
    #   explicit changes to the buffer (e.g. a logged message, added tags or
    #   fields), the buffer will not be flushed to the sink but will be silently
    #   dropped.
    def initialize(sink, buffering: true, allow_empty: false)
      @sink = sink
      @buffering = !!buffering
      @allow_empty = !!allow_empty

      # initialize the internal data structures for fields, tags, ...
      clear
    end

    # Add a new message to the buffer. This will mark the current buffer as
    # {pending?} and will result in the eventual flush of the logged data.
    #
    # If the buffer is not {#buffering?}, it will be {#flush}ed and {#clear}ed
    # after each added message. All fields and tags added before the log message
    # will be flushed along with the single message.
    #
    # @param message [Message] A {Message} to add to the current message
    #   buffer.
    # @return [Message] the passed `message`
    def add_message(message)
      @messages << message
      timestamp(message.time)

      unless buffering?
        flush
        clear
      end

      message
    end

    # When set to `true` in {#initialize}, the data in this buffer will be
    # flushed to the sink, even if no messages were logged but there were just
    # added fields or tags. If this is `false` and there were no explicit
    # changes to the buffer (e.g. a logged message, added tags or fields), the
    # buffer will not be flushed to the sink but will be silently dropped.
    #
    # @return [Boolean]
    def allow_empty?
      @allow_empty
    end

    # When set to `true` in {#initialize}, this buffer is considered to be
    # buffering data. When buffering, logged messages will not be flushed
    # immediately but only with an explicit call to {#flush}.
    #
    # @return [Boolean] true if the current buffer is intended to hold buffered
    #   data of multiple log calls
    def buffering?
      @buffering
    end

    # Clear the current buffer from all stored data, just as it was right after
    # inititialization.
    #
    # @return [self]
    def clear
      @messages = Concurrent::Array.new
      @fields = Rackstash::Fields::Hash.new(forbidden_keys: FORBIDDEN_FIELDS)
      @tags = Rackstash::Fields::Tags.new
      @timestamp = nil

      self
    end

    # Flush the current buffer to the log sink. Does nothing if the buffer is
    # not pending.
    #
    # @return [self,nil] returns `self` if the buffer was flushed, `nil`
    #   otherwise
    def flush
      return unless pending?

      @sink.flush(self)
      self
    end

    # Return all logged messages on the current buffer.
    #
    # @return [Array<Message>] the list of messages of the curent buffer
    # @note You can not add messsages to the buffer by modifying this array.
    #   Instead, use {#add_message} to add new messages or add filters to the
    #   responsible codec to remove or change messages.
    def messages
      @messages.dup
    end

    # This flag denotes whether the current buffer holds flushable data. By
    # default, a new buffer is not pending and will not be flushed to the sink.
    # Each time there is a new message logged, this is set to `true` for the
    # buffer. For changes of tags or fields, the `pending?` flag is only
    # flipped to `true` if {#allow_empty?} is set to `true`.
    #
    # @return [Boolean] `true` if the buffer has stored data which should be
    #   flushed.
    def pending?
      return true if @messages.any?
      if allow_empty?
        return true unless @fields.empty?
        return true unless @tags.empty?
      end
      false
    end

    # Set tags on the buffer. Any values given here are appended to the set of
    # currently defined tags.
    #
    # You can give the tags either as Strings, Arrays of Strings or Procs which
    # return Strings or Arrays of Strings when called. Each Proc will be called
    # as it is set on the buffer. If you pass the optional `scope` value, the
    # Procs will be evaluated in the context of this scope.
    #
    # @param tags [Array<#to_s, #call>] Strings to add as tags to the buffer.
    #   You can either give (arrays of) strings here or procs which return
    #   a string or an array of strings when called.
    # @param scope [nil, Object] If anything other then `nil` is given here, we
    #   will evaluate any procs given in the tags in the context of this
    #   object. If `nil` is given (the default) the procs are directly called
    #   in the context where they were created.
    # @return [Fields::Tags] the resolved tags which are set on the buffer.
    #   All strings are frozen.
    def tag(*tags, scope: nil)
      @tags.merge!(tags, scope: scope)
    end

    # Returns the time of the current buffer as an ISO 8601 formatted string.
    # If the timestamp was not yet set on the buffer, it is is set to the
    # the passed `time` or the current time.
    #
    # @example
    #   buffer.timestamp
    #   # => "2016-10-17T13:37:00.234Z"
    # @param time [Time] an optional time object. If no timestamp was set yet,
    #   this time is used
    # @return [String] an ISO 8601 formatted UTC timestamp.
    def timestamp(time = nil)
      @timestamp ||= begin
        time ||= Time.now
        time.utc.iso8601(ISO8601_PRECISION).freeze
      end
    end
  end
end
