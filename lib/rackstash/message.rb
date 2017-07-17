# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # This class and all its data are immutable after initialization
  class Message
    attr_reader :message

    alias as_json message
    # Messages are implicitly conversible to Strings
    alias to_s message
    alias to_str message

    attr_reader :severity

    attr_reader :progname

    attr_reader :time

    def initialize(message, severity: UNKNOWN, time: Time.now.utc.freeze, progname: PROGNAME)
      @severity = Integer(severity)
      @severity = 0 if @severity < 0

      @time = dup_freeze(time)
      @progname = dup_freeze(progname)

      @message = cleanup(message)
    end

    # @return [String] the guman readable label for the {#severity}.
    # @see {Rackstash.severity_label}
    def severity_label
      Rackstash.severity_label(@severity)
    end

    # @return [Integer] the character length of {#message}.
    def length
      @message.length
    end
    alias size length

    def to_json
      as_json.to_json
    end

    private

    # Sanitize a single mesage to be added to the buffer, can be a single or
    # multi line string
    #
    # @param msg [#to_s] a message to be added to the buffer
    # @return [String] the sanitized frozen message
    def cleanup(msg)
      msg = msg.inspect unless msg.is_a?(String)
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
