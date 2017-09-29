# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/message'

describe Rackstash::Encoders::Message do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'gets the message from the event hash' do
      event = { 'hello' => 'world', 'message' => ["\n\t \nline1\n", "line2\n  \n\t\n"] }
      expect(encoder.encode(event)).to eql "\n\t \nline1\nline2\n  \n\t\n"
    end
  end
end
