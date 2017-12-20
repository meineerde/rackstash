# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'securerandom'

require 'rackstash/filter'

describe Rackstash::Filter do
  let(:registry) { Rackstash::ClassRegistry.new('filter') }

  let(:filter_class) {
    Class.new do
      def call(event)
        'filtered'
      end
    end
  }
  let(:filter_name) { :"filter_class_#{SecureRandom.hex(6)}" }

  describe '.build' do
    before do
      allow(described_class).to receive(:registry).and_return(registry)
      described_class.register(filter_class, filter_name)
    end

    it 'builds a filter from a class' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_class, *args)
    end

    it 'builds a filter from a Symbol' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_name.to_sym, *args)
    end

    it 'builds a filter from a String' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_name.to_s, *args)
    end

    it 'returns an existing filter' do
      filter = -> {}

      expect(described_class.build(filter)).to equal filter
      expect(described_class.build(filter, :ignored, 42)).to equal filter
    end

    it 'raises a TypeError with invalid spec types' do
      expect { described_class.build(123) }
        .to raise_error(TypeError, '123 can not be used to describe filters')
      expect { described_class.build(nil) }
        .to raise_error(TypeError, 'nil can not be used to describe filters')
      expect { described_class.build(true) }
        .to raise_error(TypeError, 'true can not be used to describe filters')
    end

    it 'raises a KeyError for undefined filters' do
      expect { described_class.build('MissingFilter') }
        .to raise_error(KeyError, 'No filter was registered for "MissingFilter"')
      expect { described_class.build(:missing_filter) }
        .to raise_error(KeyError, 'No filter was registered for :missing_filter')
    end
  end

  describe 'registry' do
    it 'returns the filter registry' do
      expect(described_class.registry).to be_instance_of Rackstash::ClassRegistry
      expect(described_class.registry.object_type).to eql 'filter'
    end
  end
end
