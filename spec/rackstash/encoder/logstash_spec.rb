# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/logstash'

describe Rackstash::Encoder::Logstash do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'formats the passed event hash as JSON and adds @version and @timstamp' do
      event = { 'hello' => 'world', 'message' => ["hello\n", 'world'] }
      expect(encoder.encode(event))
        .to match(/\A\{"hello":"world","message":"hello\\nworld","@version":"1","@timestamp":"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z"\}\z/)
    end

    it 'keeps an existing @version field' do
      event = { 'foo' => 'bar', '@version' => '2.5' }
      expect(encoder.encode(event))
        .to match(/\A{"foo":"bar","@version":"2.5","@timestamp":"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z"\}\z/)
    end

    it 'formats an existing @timestamp field' do
      time = Time.parse('2016-10-17 13:37:00 +03:00')
      event = { 'message' => 'msg', '@timestamp' => time }

      expect(encoder.encode(event))
        .to eql '{"message":"msg","@timestamp":"2016-10-17T10:37:00.000000Z","@version":"1"}'
    end
  end
end
