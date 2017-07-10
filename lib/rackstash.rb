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

  SEVERITY_NAMES = {
    'debug' => DEBUG,
    'info' => INFO,
    'warn' => WARN,
    'error' => ERROR,
    'fatal' => FATAL,
    'unknown' => UNKNOWN
  }.freeze

  SEVERITY_LABELS = [
    'DEBUG'.freeze,
    'INFO'.freeze,
    'WARN'.freeze,
    'ERROR'.freeze,
    'FATAL'.freeze,
    'ANY'.freeze
  ].freeze

  PROGNAME = "rackstash/v#{Rackstash::VERSION}".freeze

  EMPTY_STRING = ''.freeze
  EMPTY_SET = Set.new.freeze

  # How many decimal places to render on ISO 8601 timestamps
  ISO8601_PRECISION = 3

  FIELD_MESSAGE = 'message'.freeze
  FIELD_TAGS = 'tags'.freeze
  FIELD_TIMESTAMP = '@timestamp'.freeze
  FIELD_VERSION = '@version'.freeze

  def self.severity_label(severity)
    if severity.is_a?(Integer)
      SEVERITY_LABELS[severity] || SEVERITY_LABELS.last
    else
      severity = SEVERITY_NAMES.fetch(severity.to_s.downcase, UNKNOWN)
      SEVERITY_LABELS[severity]
    end
  end
end

require 'rackstash/logger'

require 'rackstash/adapters/callable'
require 'rackstash/adapters/file'
require 'rackstash/adapters/io'
