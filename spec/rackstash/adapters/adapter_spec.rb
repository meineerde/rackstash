# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/adapters/adapter'

describe Rackstash::Adapters::Adapter do
  let(:adapter) { Rackstash::Adapters::Adapter.new }

  describe '#initialize' do
    it 'accepts any arguments' do
      Rackstash::Adapters::Adapter.new
      Rackstash::Adapters::Adapter.new(:foo)
      Rackstash::Adapters::Adapter.new(123, [:foo])
    end
  end

  describe '#close' do
    it 'does nothing' do
      expect(adapter.close).to be nil
    end
  end

  describe '#reopen' do
    it 'does nothing' do
      expect(adapter.reopen).to be nil
    end
  end

  describe '#write' do
    it 'calls write_single' do
      expect(adapter).to receive(:write_single).with('a log line')
      adapter.write('a log line')
    end
  end

  describe '#write_single' do
    it 'is not implemented in the abstract base class' do
      expect { adapter.write('something') }.to raise_error(NotImplementedError)
    end
  end
end
