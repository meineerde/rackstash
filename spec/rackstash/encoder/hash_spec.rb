# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/hash'

RSpec.describe Rackstash::Encoder::Hash do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'normalized the message' do
      event = { 'message' => ['hello', 'world'] }
      expect(encoder.encode(event)).to eql 'message' => "hello\nworld"
    end

    it 'normalizes the timestamp' do
      time = Time.now
      event = { 'message' => ['foo', 'bar'], '@timestamp' => time }

      expect(encoder.encode(event))
        .to eql 'message' => "foo\nbar", '@timestamp' => time.getutc.iso8601(6)
    end

    it 'passes the normalized event hash through' do
      event = { 'foo' => 'bar', 'baz' => :boing }
      expect(encoder.encode(event))
        .to eql 'foo' => 'bar', 'baz' => :boing
    end
  end
end
