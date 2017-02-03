# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/buffer_stack'

describe Rackstash::BufferStack do
  let(:sink) { instance_double(Rackstash::Sink) }
  let(:stack) { Rackstash::BufferStack.new(sink) }

  describe '#with_buffer' do
    it 'initializes a buffer' do
      stack.with_buffer do |buffer|
        expect(buffer).to be_a Rackstash::Buffer
        expect(buffer.sink).to equal sink
      end
    end
  end
end
