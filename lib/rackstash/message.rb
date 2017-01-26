# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # This class and all its data are immutable after initialization
  class Message
    RAW_FORMATTER = RawFormatter.new

    SEVERITY_LABEL = [
      'DEBUG'.freeze,
      'INFO'.freeze,
      'WARN'.freeze,
      'ERROR'.freeze,
      'FATAL'.freeze,
      'ANY'.freeze
    ].freeze

    attr_reader :message

    attr_reader :severity

    attr_reader :progname

    attr_reader :time

    attr_reader :formatter

    def initialize(
      msg,
      severity: UNKNOWN,
      time: Time.now.utc.freeze,
      progname: PROGNAME,
      formatter: RAW_FORMATTER
    )
      @message = dup_freeze(msg)

      @severity = Integer(severity)
      @severity = 0 if @severity < 0

      @time = dup_freeze(time)
      @progname = dup_freeze(progname)
      @formatter = formatter

      # Freeze the newly created message to ensure it can't be changed.
      # All passed values are also effectively frozen, making the Message an
      # immutable object.
      freeze
    end

    def severity_label
      SEVERITY_LABEL[@severity] || SEVERITY_LABEL.last
    end

    def to_s
      cleanup @formatter.call(severity_label, @time, @progname, @message)
    end
    alias_method :to_str, :to_s
    alias_method :as_json, :to_s

    private

    # Sanitize a single mesage to be added to the buffer, can be a single or
    # multi line string
    #
    # @param msg [#to_s] a message to be added to the buffer
    # @return [String] the sanitized frozen message
    def cleanup(msg)
      msg = utf8_encode(msg)
      # remove useless ANSI color codes
      msg.gsub!(/\e\[[0-9;]*m/, EMPTY_STRING)
      msg.freeze
    end

    def utf8_encode(str)
      str.to_s.encode(
        Encoding::UTF_8,
        invalid: :replace,
        undef: :replace,
        universal_newline: true
      )
    end

    def dup_freeze(obj)
      if obj.frozen?
        obj
      else
        obj.dup.freeze rescue obj
      end
    end
  end
end
