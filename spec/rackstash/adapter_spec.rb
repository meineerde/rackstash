# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/adapter'

RSpec.describe Rackstash::Adapter do
  around(:each) do |example|
    types = described_class.send(:adapter_types)
    schemes = described_class.send(:adapter_schemes)

    described_class.instance_variable_set(:@adapter_types, nil)
    described_class.instance_variable_set(:@adapter_schemes, nil)

    example.run

    described_class.instance_variable_set(:@adapter_types, types)
    described_class.instance_variable_set(:@adapter_schemes, schemes)
  end

  let(:adapter) {
    Class.new(Rackstash::Adapter::BaseAdapter) do
      def self.from_uri(*args)
        new(*args)
      end
    end
  }

  describe '#register' do
    it 'can register a class' do
      expect {
        described_class.register adapter, Class.new
        described_class.register adapter, String
        described_class.register adapter, Numeric
        described_class.register adapter, Integer
      }.to change { described_class.send(:adapter_types).size }
        .from(0).to(4)
      expect(described_class.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a class name (upper-case String)' do
      expect {
        described_class.register adapter, '❤'
        described_class.register adapter, ''
        described_class.register adapter, 'Hello::World'
      }.to change { described_class.send(:adapter_types).size }
        .from(0).to(3)

      # Registering 'Hello::World' a second time overwrites the first one
      expect {
        described_class.register(adapter, 'Hello::World')
      }.not_to change { described_class.send(:adapter_types).size }

      expect(described_class.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a method name (symbol)' do
      expect {
        described_class.register adapter, :foo
      }.to change { described_class.send(:adapter_types).size }
        .from(0).to(1)
      expect(described_class.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a proc' do
      expect {
        described_class.register adapter, ->(o) { o.respond_to?(:write) }
        described_class.register adapter, -> {}
      }.to change { described_class.send(:adapter_types).size }
        .from(0).to(2)
      expect(described_class.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a scheme (lower-case String)' do
      expect {
        described_class.register adapter, 'customscheme'
      }.to change { described_class.send(:adapter_schemes).size }
        .from(0).to(1)
      expect(described_class.send(:adapter_types).size).to eql 0
    end

    it 'rejects invalid adapter classes' do
      expect { described_class.register nil, :foo }
        .to raise_error(TypeError)
      expect { described_class.register Class.new, :foo }
        .to raise_error(TypeError)
    end

    it 'rejects invalid matchers' do
      matcher = Object.new
      matcher.instance_eval do
        undef :===
      end

      expect { described_class.register(adapter, matcher) }
        .to raise_error(TypeError)
    end
  end

  describe '#[]' do
    context 'with a registered class' do
      let(:device_class) { Class.new }

      before do
        described_class.register adapter, device_class
      end

      it 'creates an adapter if the class was found' do
        device = device_class.new

        expect(device_class).to receive(:===).with(device).and_call_original
        expect(adapter).to receive(:new).with(device).and_call_original
        expect(described_class[device]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'creates an adapter if any parent class was found' do
        inherited_device = Class.new(device_class).new

        expect(device_class).to receive(:===).with(inherited_device).and_call_original
        expect(adapter).to receive(:new).with(inherited_device).and_call_original
        expect(described_class[inherited_device]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'raises if no class was found' do
        expect(adapter).to_not receive(:new)
        expect { described_class['foo'] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered class name' do
      before do
        class SpecDevice; end
        class InheritedSpecDevice < SpecDevice; end

        described_class.register adapter, 'SpecDevice'
      end

      after do
        Object.send :remove_const, :InheritedSpecDevice
        Object.send :remove_const, :SpecDevice
      end

      it 'creates an adapter if the class was found' do
        device = SpecDevice.new

        expect(adapter).to receive(:new).with(device).and_call_original
        expect(described_class[device]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'creates an adapter if any parent class was found' do
        inherited_device = InheritedSpecDevice.new

        expect(adapter).to receive(:new).with(inherited_device).and_call_original
        expect(described_class[inherited_device]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'raises if no class was found' do
        expect(adapter).to_not receive(:new)
        expect { described_class['foo'] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered symbol' do
      before do
        described_class.register adapter, :foo
      end

      it 'creates an adapter if it responds to the registered method' do
        device = Struct.new(:foo).new('foo')

        expect(adapter).to receive(:new).with(device).and_call_original
        expect(described_class[device]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'raises if it does not respond to the registered method' do
        device = Struct.new(:bar).new('bar')

        expect(adapter).to_not receive(:new)
        expect { described_class[device] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered proc' do
      let(:device) { Object.new }

      it 'creates an adapter if the proc returns true' do
        checker = proc { true }
        described_class.register adapter, checker

        expect(checker).to receive(:===).with(device).and_call_original
        expect(adapter).to receive(:new).with(device).and_call_original
        expect(described_class[device]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'does not create an adapter if the proc returns false' do
        checker = proc { false }
        described_class.register adapter, checker

        expect(checker).to receive(:===).with(device).and_call_original
        expect(adapter).to_not receive(:new)
        expect { described_class[device] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered scheme' do
      before do
        described_class.register adapter, 'dummy'
        described_class.register adapter, 'foo+dummy'
      end

      it 'creates an adapter from the scheme' do
        raw_uri = 'dummy://example.com'
        expect(adapter).to receive(:from_uri).with(URI(raw_uri)).and_call_original
        expect(described_class[raw_uri]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'can use a complex scheme' do
        raw_uri = 'foo+dummy://example.com'
        expect(adapter).to receive(:from_uri).with(URI(raw_uri)).and_call_original
        expect(described_class[raw_uri]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'calls adapter.new if adapter.from_uri is not available' do
        plain_adapter = Class.new(Rackstash::Adapter::BaseAdapter)
        described_class.register plain_adapter, 'dummy'

        raw_uri = 'dummy://example.com'
        expect(plain_adapter).to receive(:new).with(URI(raw_uri)).and_call_original

        expect(described_class[raw_uri]).to be_a plain_adapter
      end

      it 'creates an adapter from a URI' do
        uri = URI('dummy://example.com')
        expect(adapter).to receive(:from_uri).with(uri).and_call_original
        expect(described_class[uri]).to be_an Rackstash::Adapter::BaseAdapter
      end

      it 'raises if no scheme was found' do
        expect(adapter).to_not receive(:new)
        expect(adapter).to_not receive(:from_uri)
        expect { described_class['unknown://example.com'] }
          .to raise_error(ArgumentError)
        expect { described_class[URI('unknown://example.com')] }
          .to raise_error(ArgumentError)
      end

      context 'and a registered class' do
        before do
          described_class.register adapter, Object
        end

        it 'falls though on invalid URI' do
          invalid_uri = '::'

          expect(adapter).to_not receive(:from_uri)
          # from the fallback
          expect(adapter).to receive(:new).with(invalid_uri).and_call_original
          expect(described_class[invalid_uri]).to be_an Rackstash::Adapter::BaseAdapter
        end

        it 'falls though if no scheme was found' do
          unknown_uri = 'unknown://example.com'

          expect(adapter).to_not receive(:from_uri)
          expect(adapter).not_to receive(:new)
          expect { described_class[unknown_uri] }
            .to raise_error ArgumentError, "No log adapter found for URI unknown://example.com"
        end
      end
    end

    context 'with an existing adapter object' do
      it 'just returns the object' do
        adapter_instance = adapter.new
        described_class.register adapter, Object

        expect(adapter).to_not receive(:new)
        expect(described_class[adapter_instance]).to equal adapter_instance
      end
    end
  end
end
