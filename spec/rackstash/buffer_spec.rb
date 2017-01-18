# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/buffer'

describe Rackstash::Buffer do
  let(:buffer) { Rackstash::Buffer.new }

  describe '#add_message' do
    it 'adds a message to the buffer' do
      msg = double(message: 'Hello World')
      buffer.add_message msg

      expect(buffer.messages).to eql [msg]
    end
  end

  describe 'messages' do
    it 'returns an array of messages' do
      msg = double('Rackstash::Message')
      buffer.add_message(msg)

      expect(buffer.messages).to eql [msg]
    end

    it 'returns a new array each time' do
      expect(buffer.messages).not_to equal buffer.messages

      expect(buffer.messages).to eql []
      buffer.messages << 'invalid'
      expect(buffer.messages).to eql []
    end
  end
end
