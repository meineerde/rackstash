# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/version'

module Rackstash
  SEVERITIES = [
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
    FATAL = 4,
    UNKNOWN = 5
  ].freeze

  PROGNAME = "rackstash/v#{Rackstash::VERSION}".freeze

  EMPTY_STRING = ''.freeze
end

require 'rackstash/logger'
