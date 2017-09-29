# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/message'

describe Rackstash::Encoders::Message do
  let(:tagged) { [] }
  let(:encoder) { described_class.new(tagged: tagged) }

  describe '#encode' do
    it 'gets the message from the event hash' do
      event = { 'hello' => 'world', 'message' => ["\n\t \nline1\n", "line2\n  \n\t\n"] }
      expect(encoder.encode(event)).to eql "\n\t \nline1\nline2\n  \n\t\n"
    end

    context 'with prefix_fields' do
      let(:tagged) { [:sym, 'field', 'tags'] }

      it 'adds fields to all lines' do
        event = { 'message' => ["line1\t\n", "line2\nline3\n\t\n"], 'field' => 'BXC' }
        expect(encoder.encode(event))
          .to eql "[BXC] line1\t\n[BXC] line2\n[BXC] line3\n[BXC] \t\n"
      end

      it 'uses stringified fields' do
        event = { 'message' => ["line1\n", "line2\nline3\n"], 'sym' => 'SYM', 'field' => 123 }
        expect(encoder.encode(event))
          .to eql "[SYM] [123] line1\n[SYM] [123] line2\n[SYM] [123] line3\n"
      end

      it 'formats arrays' do
        event = { 'message' => ["line1\n", "line2\n"], 'tags' => ['foo', 'bar'] }
        expect(encoder.encode(event)).to eql "[foo,bar] line1\n[foo,bar] line2\n"
      end

      it 'ignores missing fields' do
        event = { 'message' => ["line1\n", "line2\n"] }
        expect(encoder.encode(event)).to eql "line1\nline2\n"
      end
    end
  end
end
