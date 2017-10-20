# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'securerandom'

require 'rackstash/filters'

describe Rackstash::Filters do
  let(:filter_class) { Class.new }
  let(:random) { SecureRandom.hex(6) }
  let(:filter_class_name) { :"FilterClass#{random}" }

  around(:each) do |example|
    described_class.const_set(filter_class_name, filter_class)
    example.run
    described_class.send(:remove_const, filter_class_name)
  end

  describe '.build' do
    it 'builds a filter from a class' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_class, *args)
    end

    it 'builds a filter from a Symbol' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(:"filter_class#{random}", *args)
    end

    it 'builds a filter from a String' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build("filter_class#{random}", *args)
    end

    it 'returns an existing filter' do
      filter = -> {}
      expect(described_class.build(filter)).to equal filter
      expect(described_class.build(filter, :ignored, 42)).to equal filter
    end

    it 'raises a TypeError with different arguments' do
      expect { described_class.build(123) }.to raise_error(TypeError)
      expect { described_class.build(nil) }.to raise_error(TypeError)
      expect { described_class.build(true) }.to raise_error(TypeError)

      expect { described_class.build('MissingFilter') }.to raise_error(NameError)
      expect { described_class.build(:missing_filter) }.to raise_error(NameError)
    end
  end

  describe '.known' do
    it 'returns a Hash with known Filters' do
      expect(described_class.known).not_to be_empty

      expect(described_class.known.keys).to all(
        be_a(Symbol)
        .and match(/\A[a-z0-9_]+\z/)
      )
      expect(described_class.known.values).to all be_a(Class)
    end

    it 'includes Filter classes' do
      expect(described_class.known[:"filter_class#{random}"]).to equal filter_class
    end
  end
end
