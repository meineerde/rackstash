# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # The default logging formatter which is responsible for formatting a single
  # {Message} for the final emitted log event.
  class Formatter
    include Rackstash::Utils

    # Return the formatted message from the following rules:
    # * Strings passed to `msg` are returned as a UTF-8 encoded frozen String
    # * Exceptions are formatted with their name, message and backtrace,
    #   separated by newline characters.
    # * All other objects will be `inspect`ed and returned as a UTF-8 encoded
    #   frozen String.
    #
    # @param _severity [Integer] the log severity, ignored.
    # @param _time [Time] the time of the log message, ignored.
    # @param _progname [String] the program name, ignored.
    # @param msg [String, Exception, #inspect] the log message
    # @return [String] the formatted message
    def call(_severity, _time, _progname, msg)
      case msg
      when ::String
       utf8(msg)
      when ::Exception
        lines = ["#{msg.message} (#{msg.class})"]
        lines.concat(msg.backtrace) if msg.backtrace

        utf8 lines.join("\n").freeze
      else
        utf8(msg.inspect)
      end
    end
  end
end
