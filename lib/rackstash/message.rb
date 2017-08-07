# frozen_string_literal: true

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
