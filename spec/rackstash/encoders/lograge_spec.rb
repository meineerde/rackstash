# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/lograge'

describe Rackstash::Encoders::Lograge do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'formats the timestamp if present' do
      event = { '@timestamp' => Time.new(2016, 10, 17, 16, 37, 0, '+03:00') }
      expect(encoder.encode(event))
        .to eql 'timestamp=2016-10-17T13:37:00.000000Z'
    end

    it 'formats multiple values' do
      event = { 'pling' => 'plong', 'toot' => 'chirp' }
      expect(encoder.encode(event))
        .to eql 'pling=plong toot=chirp'
    end

    it 'formats nested objects' do
      event = { 'pling' => ['plong', nil, { 'toot' => { 'bird' => ['chirp', 'tweet'] } }] }
      expect(encoder.encode(event))
        .to eql 'pling.0=plong pling.2.toot.bird.0=chirp pling.2.toot.bird.1=tweet'
    end

    it 'formats float values' do
      event = { 'key' => 3.14159, 'rounded' => 4.947 }
      expect(encoder.encode(event)).to eql 'key=3.14 rounded=4.95'
    end

    it 'formats complex errors' do
      event = {
        'error' => 'RuntimeError',
        'error_message' => 'Something',
        'error_trace' => "Foo\nBar\nBaz",

        'nested' => {
          'error' => 'NestedError',
          'error_message' => 'a message'
        }
      }

      expect(encoder.encode(event))
        .to eql "error='RuntimeError: Something' nested.error=NestedError nested.error_message=a message"
    end

    it 'formats an error' do
      event = { 'error' => 'StandardError' }
      expect(encoder.encode(event)).to eql "error='StandardError'"
    end

    it 'formats an error_message' do
      event = { 'error_message' => 'Something happened' }
      expect(encoder.encode(event)).to eql "error='Something happened'"
    end

    it 'ignores dots, spaces and equal signs' do
      event = { 'some.key' => 'a.value', 'a=b' => 'c=d', 'a key' => 'some value' }
      expect(encoder.encode(event))
        .to eql 'some.key=a.value a=b=c=d a key=some value'
    end

    it 'ignores all messages' do
      event = { 'key' => 'value', 'message' => ['foo', 'bar'] }
      expect(encoder.encode(event)).to eql 'key=value'
    end
  end
end
