# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/logstash'

describe Rackstash::Encoders::Logstash do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'formats the passed event hash as a JSON string and includes @version' do
      event = { 'hello' => 'world', 'message' => ["hello\n", "world"] }
      expect(encoder.encode(event))
        .to match(/\A\{"hello":"world","message":"hello\\nworld","@version":"1","@timestamp":"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z"\}\z/)
    end
  end
end
