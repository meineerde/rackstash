# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'set'

require 'rackstash/version'

module Rackstash
  # A custom error which is raised by methods which need to be implemented
  # elsewhere, usually in a subclass. Please refer to the documentation of the
  # method which raised this error for details.
  #
  # Note that this error is not a `StandardError` and will not be rescued
  # unless it or any of its ancestors, e.g. `Exception` is specified explicitly.
  class NotImplementedHereError < ScriptError; end

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

  # Gets the label for a given severity. You can specify the severity either by
  # its numeric value or its name in most variations (`Symbol`, `String`,
  # different cases).
  #
  # If the given severity if unknown or out of range, we return `"ANY"`.
  #
  # @param severity [Integer, #to_s] A numeric value of one of the {SEVERITIES}
  #   or a {SEVERITY_NAMES} key
  # @return [String] one of the {SEVERITY_LABELS}
  def self.severity_label(severity)
    if severity.is_a?(Integer)
      return SEVERITY_LABELS.last if severity < 0
      SEVERITY_LABELS[severity] || SEVERITY_LABELS.last
    else
      severity = SEVERITY_NAMES.fetch(severity.to_s.downcase, UNKNOWN)
      SEVERITY_LABELS[severity]
    end
  end

  # Resolve a given severity to its numeric value. You can specify the severity
  # either by its numeric value (generally one of the {SEVERITIES}), or its name
  # in most variations (`Symbol`, `String`, different cases), i.e. one of the
  # {SEVERITY_NAMES}.
  #
  # If an invalid severity name is given, we raise an `ArgumentError`. All
  # Integer values are accepted without further checks.
  #
  # @param severity [Integer, #to_s] A numeric value of one of the {SEVERITIES}
  #   or a {SEVERITY_NAMES} key)
  # @raise [ArgumentError] if an invalid severity name is given.
  # @return [Integer] the resolved severity
  def self.severity(severity)
    return severity if severity.is_a?(Integer)

    SEVERITY_NAMES.fetch(severity.to_s.downcase) do
      raise ArgumentError, "invalid log severity: #{severity.inspect}"
    end
  end

  PROGNAME = "rackstash/v#{Rackstash::VERSION}".freeze

  # A class for the {UNDEFINED} object. Generally, there will only be exactly
  # one object of this class.
  #
  # The {UNDEFINED} object can be used as the default value for method arguments
  # to distinguish it from `nil`. See https://holgerjust.de/2016/detecting-default-arguments-in-ruby/#special-default-value
  # for details.
  class UndefinedClass
    # @return [Boolean] `true` iff `other` is the exact same object as `self`
    def ==(other)
      self.equal?(other)
    end
    alias === ==
    alias eql? ==

    # @return [String] the string `"undefined"`
    def to_s
      'undefined'.freeze
    end
    alias inspect to_s
  end

  UNDEFINED = UndefinedClass.new.tap do |undefined|
    class << undefined.class
      undef_method :allocate
      undef_method :new
    end
  end

  EMPTY_STRING = ''.freeze
  EMPTY_SET = Set.new.freeze

  # How many decimal places to render on ISO 8601 timestamps
  ISO8601_PRECISION = 6

  FIELD_MESSAGE = 'message'.freeze
  FIELD_TAGS = 'tags'.freeze
  FIELD_TIMESTAMP = '@timestamp'.freeze
  FIELD_VERSION = '@version'.freeze

  FIELD_ERROR = 'error'.freeze
  FIELD_ERROR_MESSAGE = 'error_message'.freeze
  FIELD_ERROR_TRACE = 'error_trace'.freeze

  FIELD_DURATION = 'duration'.freeze
  FIELD_METHOD = 'method'.freeze
  FIELD_PATH = 'path'.freeze
  FIELD_SCHEME = 'scheme'.freeze
  FIELD_STATUS = 'status'.freeze

  # Returns a {Flow} which is used by the normal logger {Flow}s to write details
  # about any unexpected errors during interaction with their {Adapter}s.
  #
  # By default, this Flow logs JSON-formatted messages to `STDERR`
  #
  # @return [Rackstash::Flow] the default error flow
  def self.error_flow
    @error_flow ||= Rackstash::Flow.new(STDERR)
  end

  # Set a {Flow} which is used bythe normal logger {Flow}s to write details
  # of any unexpected errors during interaction with their {Adapter}s.
  #
  # You can set a different `error_flow` for each {Flow} if required. You can
  # also change this flow to match your desired fallback format and log adapter.
  #
  # To still work in the face of unexpected availability issues like a full
  # filesystem, an unavailable network, broken external loggers, or any other
  # external issues, it is usually desireable to chose a local and mostly
  # relibable log target.
  #
  # @param flow [Flow, Adapter::Adapter, Object] a single {Flow} or an object
  #   which can be used as a {Flow}'s adapter. See {Flow#initialize}.
  # @return [Rackstash::Flow] the given `flow`
  def self.error_flow=(flow)
    flow = Flow.new(flow) unless flow.is_a?(Rackstash::Flow)
    @error_flow = flow
  end
end

require 'rackstash/logger'

require 'rackstash/adapter/callable'
require 'rackstash/adapter/file'
require 'rackstash/adapter/logger'
require 'rackstash/adapter/io'
require 'rackstash/adapter/null'

require 'rackstash/encoder/hash'
require 'rackstash/encoder/json'
require 'rackstash/encoder/lograge'
require 'rackstash/encoder/logstash'
require 'rackstash/encoder/message'
require 'rackstash/encoder/raw'

require 'rackstash/filter/clear_color'
require 'rackstash/filter/default_fields'
require 'rackstash/filter/default_tags'
require 'rackstash/filter/drop_if'
require 'rackstash/filter/rename'
require 'rackstash/filter/replace'
require 'rackstash/filter/truncate_message'
require 'rackstash/filter/update'
