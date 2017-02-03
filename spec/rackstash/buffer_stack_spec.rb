# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/buffer_stack'

describe Rackstash::BufferStack do
  let(:sink) { instance_double(Rackstash::Sink) }
  let(:stack) { Rackstash::BufferStack.new(sink) }

  describe '#current' do
    it 'initializes a buffer' do
      expect(stack.current).to be_a Rackstash::Buffer
      expect(stack.current.sink).to equal sink
    end

    it 'repeatedly returns the same buffer' do
      expect(stack.current).to equal stack.current
    end
  end
end
