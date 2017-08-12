# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/json'

describe Rackstash::Encoders::JSON do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'formats the passed event hash as a JSON string' do
      event = { 'hello' => 'world', 'message' => 'hello' }
      expect(encoder.encode(event)).to eql '{"hello":"world","message":"hello"}'
    end

    it 'formats newlines as \n' do
      event = { 'message' => "text\nwith\nnewlines" }
      expect(encoder.encode(event)).to eql '{"message":"text\nwith\nnewlines"}'
    end

    it 'strips the message from all surrounding whitespace' do
      event = { 'message' => "\n\t \nline1\nline2\n  \n\t\n" }
      expect(encoder.encode(event)).to eql '{"message":"line1\nline2"}'
    end

    it 'removes any ANSI color codes from the message' do
      event = { 'message' => "Important\n\e[31mRED TEXT\e[0m\nOK" }
      expect(encoder.encode(event)).to eql '{"message":"Important\nRED TEXT\nOK"}'
    end
  end
end
