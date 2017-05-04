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

    it 'adds a new implicit buffer' do
      expect(stack.current).to be_a Rackstash::Buffer
      stack.flush_and_pop

      expect(stack.instance_variable_get(:@stack).count).to eql 0

      expect(stack.current).to be_a Rackstash::Buffer
      expect(stack.instance_variable_get(:@stack).count).to eql 1
    end
  end

  describe '#push' do
    it 'adds a new buffer to the stack' do
      expect { stack.push }
        .to change { stack.instance_variable_get(:@stack).count }.from(0).to(1)
    end

    it 'returns the new buffer' do
      new_buffer = stack.push
      expect(new_buffer).to be_a Rackstash::Buffer
      expect(new_buffer).to equal stack.current
    end

    it 'pushes a buffering buffer by default' do
      stack.push
      expect(stack.current.buffering?).to be true
    end

    it 'allows to set options on the new buffer' do
      stack.push(buffering: false)
      expect(stack.current.buffering?).to be false
    end
  end

  describe '#flush_and_pop' do
    it 'removes a buffer from the stack' do
      stack.push
      expect { stack.flush_and_pop }
        .to change { stack.instance_variable_get(:@stack).count }.from(1).to(0)
    end

    it 'does nothing if there is no buffer' do
      expect(stack.instance_variable_get(:@stack).count).to eql 0
      expect { stack.flush_and_pop }
        .not_to change { stack.instance_variable_get(:@stack) }
    end

    it 'always returns nil' do
      stack.push
      expect(stack.flush_and_pop).to be nil
      expect(stack.flush_and_pop).to be nil
    end

    it 'flushes the removed buffer' do
      new_buffer = stack.push

      expect(new_buffer).to receive(:flush).once

      stack.flush_and_pop
      stack.flush_and_pop # no further buffer, thus `#flush` is not called again
    end
  end
end
