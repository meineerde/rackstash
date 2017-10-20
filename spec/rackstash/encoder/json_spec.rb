# frozen_string_literal: true
#
# Copyright 2017 Holger Just
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
  end
end
