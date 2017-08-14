# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/encoders/json'

module Rackstash
  module Encoders
    # The JSON encoder formats the log event as a single-line JSON string. The
    # resulting JSON string contains all data exposed by the buffer. Leading
    # and trailing whitespace as well as any ANSI color codes in the `"message"`
    # field will be removed.
    #
    # The resulting string is in the JSON format native to Logstash. You can
    # thus ship your logs directly to Logstash without further processing by
    # using Logstash's [json codec](https://www.elastic.co/guide/en/logstash/current/plugins-codecs-json.html)
    # on the input definition.
    class Logstash < JSON
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the event as a single-line JSON string
      def encode(event)
        event[FIELD_VERSION] = '1'.freeze if event[FIELD_VERSION].nil?
        super(event)
      end
    end
  end
end
