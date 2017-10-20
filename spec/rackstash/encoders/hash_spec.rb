# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/hash'

describe Rackstash::Encoders::Hash do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'normalized the message' do
      event = { 'message' => ["hello\n", "world\n", 'foo', 'bar'] }
      expect(encoder.encode(event)).to eql 'message' => "hello\nworld\nfoobar"
    end

    it 'normalizes the timestamp' do
      time = Time.now
      event = { 'message' => ['foo', 'bar'], '@timestamp' => time }

      expect(encoder.encode(event))
        .to eql 'message' => 'foobar', '@timestamp' => time.getutc.iso8601(6)
    end

    it 'passes the normalized event hash through' do
      event = { 'foo' => 'bar', 'baz' => :boing }
      expect(encoder.encode(event))
        .to eql 'foo' => 'bar', 'baz' => :boing, 'message' => ''
    end
  end
end
