# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/encoders/json'

module Rackstash
  module Encoders
    # The Logstash encoder formats the log event as a single-line JSON string in
    # the JSON format native to Logstash. You can thus ship your logs directly
    # to Logstash without further processing by using Logstash's
    # [json codec](https://www.elastic.co/guide/en/logstash/current/plugins-codecs-json.html)
    # on the input definition.
    #
    # The resulting JSON string contains all data exposed by the buffer.
    class Logstash < JSON
      # @param event [Hash] a log event as produced by the {Flow}
      # @return [String] the event as a single-line JSON string
      def encode(event)
        event[FIELD_VERSION] = '1'.freeze if event[FIELD_VERSION].nil?
        event[FIELD_TIMESTAMP] ||= Time.now.utc.freeze

        super(event)
      end
    end
  end
end
