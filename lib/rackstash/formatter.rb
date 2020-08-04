# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'logger'

module Rackstash
  # The default logging formatter which is responsible for formatting a single
  # {Message} for the final emitted log event.
  class Formatter < ::Logger::Formatter
    # Return the formatted message from the following rules:
    # * Strings passed to `msg` are returned with an added newline character at
    #   the end
    # * Exceptions are formatted with their name, message and backtrace,
    #   separated by newline characters.
    # * All other objects will be `inspect`ed with an added newline.
    #
    # @param _severity [Integer] the log severity, ignored.
    # @param _time [Time] the time of the log message, ignored.
    # @param _progname [String] the program name, ignored.
    # @param msg [String, Exception, #inspect] the log message
    # @return [String] the formatted message with a final newline character
    def call(_severity, _time, _progname, msg)
      "#{msg2str(msg)}\n".freeze
    end
  end
end
