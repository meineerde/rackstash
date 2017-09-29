# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/helpers'

module Rackstash
  # A Message wraps a single logged message created by the {Logger}. Here, we
  # store the formatted message itself plus some additional meta-data about the
  # message.
  #
  # In the end, only the `message` field will be included in the final log
  # event. However, the stored meta-data can be useful when filtering or
  # changing the messages of a log event using {Filters} later.
  #
  # All `Message` objects and their respective data are immutable after
  # initialization.
  class Message
    include Rackstash::Helpers::UTF8

    # @return [String] the logged message string. It usually is already
    #   formatted by the {Logger}'s formatter
    attr_reader :message
    alias as_json message
    alias to_s message
    alias to_str message

    # @return [Integer] the numeric severity of the logged message. Usually
    #   corresponds to one of the {SEVERITIES} constants
    attr_reader :severity

    # @return [String] the progname provided (or inferred) during logging of the
    #   message by the {Logger}.
    attr_reader :progname

    # @return [Time] the frozen timestamp of the logged message. While this
    #   timestamp is usually in UTC, it is not guaranteed.
    attr_reader :time

    # @param message [String, #inspect] a message string
    # @param severity [Integer] the numeric severity of the logged message
    # @param time [Time] the timestamp of the logged message
    # @param progname [String] the progname provided (or inferred) during
    #   logging of the message by the {Logger}.
    def initialize(message, severity: UNKNOWN, time: Time.now.utc.freeze, progname: PROGNAME)
      @severity = Integer(severity)
      @severity = 0 if @severity < 0

      @time = dup_freeze(time)
      @progname = dup_freeze(progname)

      message = message.inspect unless String === message
      @message = utf8_encode(message)

      freeze
    end

    # Create a new Message object based on the values in `self`, optionally
    # overwriting any of the them.
    #
    # @param (see #initialize)
    # @return [Message] a new Message
    def copy_with(message = nil, severity: nil, time: nil, progname: nil)
      self.class.new(
        message.nil? ? self.message : message,
        severity: severity.nil? ? self.severity : severity,
        time: time.nil? ? self.time : time,
        progname: progname.nil? ? self.progname : progname
      )
    end

    # Returns a copy of the Message with all occurances of `pattern` in the
    # `message` attribute substituted for the second argument.
    #
    # This works very similar to
    # [`String#gsub`](https://ruby-doc.org/core/String.html#method-i-gsub). We
    # are returning a new Message object herre with the `message` attribute
    # being updated. Please see the documentation of the String method for how
    # to use this.
    #
    # Note that when supplying a block for replacement, the current match string
    # is passed in as a parameter. Differing from `String#gsub`, the special
    # variables `$1`, `$2`, `$``, `$&`, and `$'` will *not* be set here.
    #
    # @param pattern [String, Regexp] the search pattern
    # @param replacement [String, Hash] the replacement definition
    # @yield match If `replacement` is not given, we yield each match to the
    #   supplied block and use its return value for the replacement
    # @return [Message, Enumerator] a new frozen Message object or an Enumerator
    #   if neither a block nor a `replacement` were given.
    def gsub(pattern, replacement = UNDEFINED, &block)
      if UNDEFINED.equal? replacement
        if block_given?
          copy_with @message.gsub(pattern, &block).freeze
        else
          return enum_for(__method__)
        end
      else
        copy_with @message.gsub(pattern, replacement, &block).freeze
      end
    end

    # Returns a copy of the Message with the first occurance of `pattern` in the
    # `message` attribute substituted for the second argument.
    #
    # This works very similar to
    # [`String#sub`](https://ruby-doc.org/core/String.html#method-i-sub). We
    # are returning a new Message object herre with the `message` attribute
    # being updated. Please see the documentation of the String method for how
    # to use this.
    #
    # Note that when supplying a block for replacement, the current match string
    # is passed in as a parameter. Differing from `String#gsub`, the special
    # variables `$1`, `$2`, `$``, `$&`, and `$'` will *not* be set here.
    #
    # @param pattern [String, Regexp] the search pattern
    # @param replacement [String, Hash] the replacement definition
    # @yield match If `replacement` is not given, we yield the match (if any) to
    #   the supplied block and use its return value for the replacement.
    # @return [Message, Enumerator] a new frozen Message object or an Enumerator
    #   if neither a block nor a `replacement` were given.
    def sub(pattern, replacement = UNDEFINED, &block)
      message =
        if UNDEFINED.equal? replacement
          @message.sub(pattern, &block)
        else
          @message.sub(pattern, replacement, &block)
        end
      copy_with(message.freeze)
    end

    # @return [Message] Returns a copy of `self` with leading whitespace
    #   removed on the `message`.
    def lstrip
      copy_with(@message.lstrip.freeze)
    end

    # @return [Message] Returns a copy of `self` with trailing whitespace
    #   removed on the `message`.
    def rstrip
      copy_with(@message.rstrip.freeze)
    end

    # @return [Message] Returns a copy of `self` with leading and trailing
    #   whitespace removed on the `message`.
    def strip
      copy_with(@message.strip.freeze)
    end

    # @return [String] the human readable label for the {#severity}.
    # @see Rackstash.severity_label
    def severity_label
      Rackstash.severity_label(@severity)
    end

    # @return [Integer] the character length of {#message}.
    def length
      @message.length
    end
    alias size length

    # @return [String] A JSON representation of the message string
    def to_json
      as_json.to_json
    end

    private

    def dup_freeze(obj)
      if obj.frozen?
        obj
      else
        obj.dup.freeze rescue obj
      end
    end
  end
end
