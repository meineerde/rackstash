# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'concurrent'

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
  # and passed on to one or more {Flow}s which send the data to an external
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
      FIELD_VERSION,    # the version of the Logstash JSON schema. Usually "1"
    ].freeze

    # @return [Sink] the log {Sink} where the buffer is eventually flushed to
    attr_reader :sink

    # @param buffering [Boolean] When set to `true`, this buffer is considered
    #   to be buffering data. When buffering, logged messages will not be
    #   flushed immediately but only with an explicit call to {#flush}.
    # @param allow_silent [Boolean] When set to `true` the data in this buffer
    #   will be flushed to the sink, even if there
    #   were just added fields or tags without any logged messages. If this is
    #   `false` and there were no messages logged with {#add_message}, the
    #   buffer will not be flushed to the sink but will be silently dropped.
    def initialize(sink, buffering: true, allow_silent: true)
      @sink = sink
      @buffering = !!buffering
      @allow_silent = !!allow_silent

      # initialize the internal data structures for fields, tags, ...
      clear
    end

    # Extract useful data from an exception and add it to fields of the buffer
    # for structured logging. The following fields will be set:
    #
    #  * `error` - The class name of the exception
    #  * `error_message` - The exception's message
    #  * `error_trace` - The backtrace of the exception, one frame per line
    #
    # The exception will not be added to the buffer's `message` field.
    # Log it manually as a message if this is desired.
    #
    # By default, the details of subsequent exceptions will overwrite those of
    # older exceptions in the current buffer. Only by the `force` argument to
    # `false`, we will preserve existing exceptions.
    #
    # @param exception [Exception] an Exception object as catched by `rescue`
    # @param force [Boolean] set to `false` to preserve the details of an
    #   existing exception in the current buffer's fields, set to `true` to
    #   overwrite them.
    # @return [Exception] the passed `exception`
    def add_exception(exception, force: true)
      return exception unless force || fields[FIELD_ERROR].nil?

      fields.merge!(
        FIELD_ERROR => exception.class.name,
        FIELD_ERROR_MESSAGE => exception.message,
        FIELD_ERROR_TRACE => (exception.backtrace || []).join("\n")
      )
      exception
    end

    # Deep-merge fields to the buffer. This will mark the current buffer as
    # {pending?} and will result in the eventual flush of the logged data.
    #
    # The buffer's timestamp will be initialized with the current time if it
    # wasn't set earlier already.
    #
    # If the buffer is not {#buffering?}, it will be {#flush}ed and {#clear}ed
    # after each added message. All fields, tags, and messages added before as
    # well as the fields added with this method call will be flushed.
    #
    # @param hash (see Fields::Hash#deep_merge!)
    # @raise (see Fields::Hash#deep_merge!)
    # @return [Rackstash::Fields::Hash, ::Hash, Proc] the given `hash` value
    #
    # @see Fields::Hash#deep_merge!
    def add_fields(hash)
      timestamp
      fields.deep_merge!(hash, force: true)
      auto_flush

      hash
    end

    # Add a new message to the buffer. This will mark the current buffer as
    # {pending?} and will result in the eventual flush of the logged data.
    #
    # The buffer's timestamp will be initialized with the time of the first
    # added message if it wasn't set earlier already.
    #
    # If the buffer is not {#buffering?}, it will be {#flush}ed and {#clear}ed
    # after each added message. All fields, tags, and messages added before as
    # well as the message added with this method call will be flushed.
    #
    # @param message [Message] A {Message} to add to the current message
    #   buffer.
    # @return [Message] the passed `message`
    def add_message(message)
      timestamp(message.time)
      @messages << message

      auto_flush

      message
    end

    # When set to `true` in {#initialize}, the data in this buffer will be
    # flushed to the sink, even if there were just added fields or tags but no
    # messages.
    #
    # If this is `false` and there were no messages logged with {#add_message},
    # the buffer will not be flushed to the sink but will be silently dropped.
    #
    # @return [Boolean]
    def allow_silent?
      @allow_silent
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
      @messages = []
      @fields = nil
      @tags = nil
      @timestamp = nil

      self
    end

    # @return [Fields::Hash] the defined fields of the current buffer in a
    #   hash-like structure
    def fields
      @fields ||= Rackstash::Fields::Hash.new(forbidden_keys: FORBIDDEN_FIELDS)
    end

    # Flush the current buffer to the log {#sink} if it is pending.
    #
    # After the flush, the existing buffer should not be used anymore. You
    # should either call {#clear} to remove all volatile data or create a new
    # buffer instance instead.
    #
    # @return [self,nil] returns `self` if the buffer was flushed, `nil`
    #   otherwise
    def flush
      return unless pending?

      @sink.write(self)
      self
    end

    # Return all logged messages on the current buffer.
    #
    # @return [Array<Message>] the list of messages of the curent buffer
    # @note You can not add messsages to the buffer by modifying this array.
    #   Instead, use {#add_message} to add new messages or add filters to the
    #   responsible {Flow} to remove or change messages.
    def messages
      @messages.dup
    end

    # This flag denotes whether the current buffer holds flushable data. By
    # default, a new buffer is not pending and will not be flushed to the sink.
    # Each time there is a new message logged, this is set to `true` for the
    # buffer. For changes of tags or fields or when setting the {#timestamp},
    # the `pending?` flag is only flipped to `true` if {#allow_silent?} is set
    # to `true`.
    #
    # @return [Boolean] `true` if the buffer has stored data which should be
    #   flushed.
    def pending?
      return true if @messages.any?
      if allow_silent?
        return true unless @timestamp.nil?
        return true unless @fields.nil? || @fields.empty?
        return true unless @tags.nil? || @tags.empty?
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
    # @param new_tags [Array<#to_s, #call>] Strings to add as tags to the buffer.
    #   You can either give (arrays of) strings here or procs which return
    #   a string or an array of strings when called.
    # @param scope [nil, Object] If anything other then `nil` is given here, we
    #   will evaluate any procs given in the tags in the context of this
    #   object. If `nil` is given (the default) the procs are directly called
    #   in the context where they were created.
    # @return [Fields::Tags] the resolved tags which are set on the buffer.
    #   All strings are frozen.
    def tag(*new_tags, scope: nil)
      timestamp
      tags.merge!(new_tags, scope: scope)
    end

    # @return [Fields::Tags] a tags list containing the defined tags for the
    #   current buffer. It contains frozen strings only.
    def tags
      @tags ||= Rackstash::Fields::Tags.new
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
        time ||= Time.now.utc.freeze
        time = time.getutc.freeze unless time.utc? && time.frozen?
        time
      end
    end

    # Create an event hash from `self`.
    #
    # * We take the buffer's existing fields and deep-merge the provided
    #   `fields` into them. Existing fields on the buffer will always have
    #   precedence here.
    # * We add the given additional `tags` to the buffer's tags and add them as
    #   a raw array of strings to the `event['tags']` field.
    # * We add the buffer's array of messages to `event['message']`. This field
    #   now contains an array of {Message} objects.
    # * We add the buffer's timestamp to the `event['@timestamp]` field as an
    #   ISO 8601 formatted string. The timestamp is always in UTC.
    #
    # The typical event emitted here looks like this:
    #
    #     {
    #       "beep" => "boop",
    #       "foo" => ["bar", "baz"],
    #       "tags" => ["request", "controller#action"],
    #       "message" => [
    #         #<Rackstash::Message:0x007f908b4414c0 ...>,
    #         #<Rackstash::Message:0x007f908d14aee0 ...>
    #       ],
    #       "@timestamp" => 2016-10-17 13:37:42 UTC
    #     }
    #
    # Note that the resulting hash still contains an Array of {Message}s in the
    # `"message"` field and a `Time` object in the '@timestamp' field. This
    # allows the {Flow}'s components (usually the {Filters} or the
    # {Flow#encoder}) to reject or adapt some messages based on
    # their original attributes, e.g., their severity or timestamp. It is the
    # responsibility of the {Flow#encoder} to correctly format the
    # `"@timestamp"` field.
    #
    # All other fields in the event Hash besides `"message"` and `@timestamp"`
    # are either `Hash`, `Array`, frozen `String`, `Integer` or `Float` objects.
    # All hashes (including nested hashes) use `String` keys.
    #
    # @param fields [Hash<String => Object>, Proc] additional fields which are
    #   merged with this Buffer's fields in the returned event Hash
    # @param tags [Array<String>, Proc] additional tags which are merged
    #   added to Buffer's tags in the returned event Hash
    # @return [Hash] the event expected by the event {Filters}.
    def to_event(fields: {}, tags: [])
      if (@fields.nil? || @fields.empty?) && ::Hash === fields && fields.empty?
        event = {}
      else
        event = self.fields.deep_merge(fields, force: false).to_h
      end

      if (@tags.nil? || @tags.empty?) && ::Array === tags && tags.empty?
        event[FIELD_TAGS] = []
      else
        event[FIELD_TAGS] = self.tags.merge(tags).to_a
      end

      event[FIELD_MESSAGE] = messages
      event[FIELD_TIMESTAMP] = timestamp

      event
    end

    private

    # Non buffering buffers, i.e., those with `buffering: false`, flush
    # themselves to the sink whenever there is something logged to it. That way,
    # such a buffer acts like a regular old Logger would: it just flushes a
    # logged message to its log device as soon as it is logged.
    #
    # By calling `auto_flush`, the current buffer is flushed and cleared

    # Flush and clear the current buffer if necessary.
    def auto_flush
      return if buffering?

      flush
      clear
    end
  end
end
