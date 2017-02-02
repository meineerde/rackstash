# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'set'

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
  EMPTY_SET = Set.new.freeze

  # How many decimal places to render on ISO 8601 timestamps
  ISO8601_PRECISION = 3
end

require 'rackstash/logger'
