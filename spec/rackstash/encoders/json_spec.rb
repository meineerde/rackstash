# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/json'

describe Rackstash::Encoders::JSON do
  let(:encoder) { Rackstash::Encoders::JSON.new }

  describe '#encode' do
    it 'formats the passed event hash as a JSON string' do
      event = { 'hello' => 'world', 'message' => 'hello' }
      expect(encoder.encode(event)).to eql '{"hello":"world","message":"hello"}'
    end

    it 'formats newlines as \n' do
      event = { 'message' => "text\nwith\nnewlines" }
      expect(encoder.encode(event)).to eql '{"message":"text\nwith\nnewlines"}'
    end

    it 'rstrips the message' do
      event = { 'message' => "line1\nline2\n  \n\t\n" }
      expect(encoder.encode(event)).to eql '{"message":"line1\nline2"}'
    end
  end
end
