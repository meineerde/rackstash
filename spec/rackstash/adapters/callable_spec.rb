# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/adapters/callable'

describe Rackstash::Adapters::Callable do
  let(:callable) { ->(log) { log } }
  let(:adapter) { described_class.new(callable) }

  describe '#initialize' do
    it 'accepts a callable' do
      expect { described_class.new(-> {}) }.not_to raise_error
      expect { described_class.new(proc {}) }.not_to raise_error
      expect { described_class.new(Struct.new(:call).new) }.not_to raise_error

      expect { described_class.new { |log| log } }.not_to raise_error
    end

    it 'rejects non-callable objects' do
      expect { described_class.new(nil) }.to raise_error TypeError
      expect { described_class.new('hello') }.to raise_error TypeError
      expect { described_class.new(Object.new) }.to raise_error TypeError
      expect { described_class.new([]) }.to raise_error TypeError
      expect { described_class.new(Struct.new(:foo).new) }.to raise_error TypeError
    end
  end

  describe '.default_encoder' do
    it 'returns a Raw encoder' do
      expect(adapter.default_encoder).to be_instance_of Rackstash::Encoders::Raw
    end
  end

  describe '#close' do
    it 'does nothing' do
      expect(callable).not_to receive(:close)
      adapter.close
    end
  end

  describe '#reopen' do
    it 'does nothing' do
      expect(callable).not_to receive(:close)
      adapter.reopen
    end
  end

  describe '#write_single' do
    it 'calls the callable with the log' do
      expect(callable).to receive(:call).with('a log line')
      adapter.write('a log line')
    end

    it 'passes through the original object' do
      expect(callable).to receive(:call).with([123, 'hello'])
      adapter.write([123, 'hello'])
    end
  end
end
