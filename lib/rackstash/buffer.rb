# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # The Buffer holds all the data of a single log event. It can hold multiple
  # messages of multiple calls to the log, additional fields holding structured
  # data about the log event, and tags identiying the type of log.
  class Buffer
    def initialize
      @messages = []
    end

    def add_message(message)
      @messages << message
    end

    def messages
      @messages.dup
    end
  end
end
