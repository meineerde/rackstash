# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/json'

describe Rackstash::Encoder::JSON do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'formats the passed event hash as a JSON string' do
      event = { 'hello' => 'world', 'message' => ["hello\n", 'world'] }
      expect(encoder.encode(event)).to eql '{"hello":"world","message":"hello\nworld"}'
    end

    it 'formats newlines as \n' do
      event = { 'message' => "text\nwith\nnewlines" }
      expect(encoder.encode(event)).to eql '{"message":"text\nwith\nnewlines"}'
    end

    it 'passes the message as nil' do
      event = { 'message' => nil, 'foo' => 'bar' }
      expect(encoder.encode(event)).to eql '{"message":null,"foo":"bar"}'
    end

    it 'omits a missing message' do
      event = { 'foo' => 'bar' }
      expect(encoder.encode(event)).to eql '{"foo":"bar"}'
    end

    it 'normalizes the timestamp' do
      time = Time.parse('2016-10-17 13:37:00 +03:00')
      event = { 'message' => ["line1\n", "line2\n"], '@timestamp' => time }

      expect(encoder.encode(event))
        .to eql '{"message":"line1\nline2\n","@timestamp":"2016-10-17T10:37:00.000000Z"}'
    end
  end
end
