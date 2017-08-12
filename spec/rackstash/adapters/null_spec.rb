# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/adapters/null'

describe Rackstash::Adapters::Null do
  let(:adapter) { described_class.new }

  describe '#initialize' do
    it 'accepts and ignores any arguments' do
      expect { described_class.new }.not_to raise_error
      expect { described_class.new(:foo, :bar, :baz) }.not_to raise_error
    end
  end

  describe '.default_encoder' do
    it 'returns a Raw encoder' do
      expect(adapter.default_encoder).to be_instance_of Rackstash::Encoders::Raw
    end
  end

  describe '#close' do
    it 'does nothing' do
      expect { adapter.close }.not_to raise_error
    end
  end

  describe '#reopen' do
    it 'does nothing' do
      expect { adapter.reopen }.not_to raise_error
    end
  end

  describe '#write_single' do
    it 'does nothing' do
      expect { adapter.write('a log line') }.not_to raise_error
    end
  end
end
