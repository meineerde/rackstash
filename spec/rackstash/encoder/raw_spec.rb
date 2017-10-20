# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/raw'

describe Rackstash::Encoder::Raw do
  let(:encoder) { described_class.new }

  describe '#encode' do
    it 'passes the raw event through' do
      event = Object.new
      expect(encoder.encode(event)).to equal event
    end
  end
end
