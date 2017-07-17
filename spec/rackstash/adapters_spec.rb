# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/adapters'

describe Rackstash::Adapters do
  around(:each) do |example|
    types = Rackstash::Adapters.send(:adapter_types)
    schemes = Rackstash::Adapters.send(:adapter_schemes)

    Rackstash::Adapters.instance_variable_set(:@adapter_types, nil)
    Rackstash::Adapters.instance_variable_set(:@adapter_schemes, nil)

    example.run

    Rackstash::Adapters.instance_variable_set(:@adapter_types, types)
    Rackstash::Adapters.instance_variable_set(:@adapter_schemes, schemes)
  end

  let(:adapter) {
    Class.new(Rackstash::Adapters::Adapter) do
      def self.from_uri(*args)
        new(*args)
      end
    end
  }

  describe '#register' do
    it 'can register a class' do
      expect {
        Rackstash::Adapters.register adapter, Class.new
        Rackstash::Adapters.register adapter, String
        Rackstash::Adapters.register adapter, Numeric
        Rackstash::Adapters.register adapter, Integer
      }.to change { Rackstash::Adapters.send(:adapter_types).size }
        .from(0).to(4)
      expect(Rackstash::Adapters.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a class name (upper-case String)' do
      expect {
        Rackstash::Adapters.register adapter, '❤'
        Rackstash::Adapters.register adapter, ''
        Rackstash::Adapters.register adapter, 'Hello::World'
      }.to change { Rackstash::Adapters.send(:adapter_types).size }
        .from(0).to(3)

      # Registering 'Hello::World' a second time overwrites the first one
      expect {
        Rackstash::Adapters.register(adapter, 'Hello::World')
      }.not_to change { Rackstash::Adapters.send(:adapter_types).size }

      expect(Rackstash::Adapters.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a method name (symbol)' do
      expect {
        Rackstash::Adapters.register adapter, :foo
      }.to change { Rackstash::Adapters.send(:adapter_types).size }
        .from(0).to(1)
      expect(Rackstash::Adapters.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a proc' do
      expect {
        Rackstash::Adapters.register adapter, ->(o) { o.respond_to?(:write) }
        Rackstash::Adapters.register adapter, -> {}
      }.to change { Rackstash::Adapters.send(:adapter_types).size }
        .from(0).to(2)
      expect(Rackstash::Adapters.send(:adapter_schemes).size).to eql 0
    end

    it 'can register a scheme (lower-case String)' do
      expect {
        Rackstash::Adapters.register adapter, 'customscheme'
      }.to change { Rackstash::Adapters.send(:adapter_schemes).size }
        .from(0).to(1)
      expect(Rackstash::Adapters.send(:adapter_types).size).to eql 0
    end

    it 'rejects invalid adapter classes' do
      expect { Rackstash::Adapters.register nil, :foo }
        .to raise_error(TypeError)
      expect { Rackstash::Adapters.register Class.new, :foo }
        .to raise_error(TypeError)
    end
  end

  describe '#[]' do
    context 'with a registered class' do
      let(:device_class) { Class.new }

      before do
        Rackstash::Adapters.register adapter, device_class
      end

      it 'creates an adapter if the class was found' do
        device = device_class.new

        expect(device_class).to receive(:===).with(device).and_call_original
        expect(adapter).to receive(:new).with(device).and_call_original
        expect(Rackstash::Adapters[device]).to be_an Rackstash::Adapters::Adapter
      end

      it 'creates an adapter if any parent class was found' do
        inherited_device = Class.new(device_class).new

        expect(device_class).to receive(:===).with(inherited_device).and_call_original
        expect(adapter).to receive(:new).with(inherited_device).and_call_original
        expect(Rackstash::Adapters[inherited_device]).to be_an Rackstash::Adapters::Adapter
      end

      it 'raises if no class was found' do
        expect(adapter).to_not receive(:new)
        expect { Rackstash::Adapters['foo'] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered class name' do
      before do
        class SpecDevice; end
        class InheritedSpecDevice < SpecDevice; end

        Rackstash::Adapters.register adapter, 'SpecDevice'
      end

      after do
        Object.send :remove_const, :InheritedSpecDevice
        Object.send :remove_const, :SpecDevice
      end

      it 'creates an adapter if the class was found' do
        device = SpecDevice.new

        expect(adapter).to receive(:new).with(device).and_call_original
        expect(Rackstash::Adapters[device]).to be_an Rackstash::Adapters::Adapter
      end

      it 'creates an adapter if any parent class was found' do
        inherited_device = InheritedSpecDevice.new

        expect(adapter).to receive(:new).with(inherited_device).and_call_original
        expect(Rackstash::Adapters[inherited_device]).to be_an Rackstash::Adapters::Adapter
      end

      it 'raises if no class was found' do
        expect(adapter).to_not receive(:new)
        expect { Rackstash::Adapters['foo'] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered symbol' do
      before do
        Rackstash::Adapters.register adapter, :foo
      end

      it 'creates an adapter if it responds to the registered method' do
        device = Struct.new(:foo).new('foo')

        expect(adapter).to receive(:new).with(device).and_call_original
        expect(Rackstash::Adapters[device]).to be_an Rackstash::Adapters::Adapter
      end

      it 'raises if it does not respond to the registered method' do
        device = Struct.new(:bar).new('bar')

        expect(adapter).to_not receive(:new)
        expect { Rackstash::Adapters[device] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered proc' do
      let(:device) { Object.new }

      it 'creates an adapter if the proc returns true' do
        checker = proc { true }
        Rackstash::Adapters.register adapter, checker

        expect(checker).to receive(:===).with(device).and_call_original
        expect(adapter).to receive(:new).with(device).and_call_original
        expect(Rackstash::Adapters[device]).to be_an Rackstash::Adapters::Adapter
      end

      it 'does not create an adapter if the proc returns false' do
        checker = proc { false }
        Rackstash::Adapters.register adapter, checker

        expect(checker).to receive(:===).with(device).and_call_original
        expect(adapter).to_not receive(:new)
        expect { Rackstash::Adapters[device] }.to raise_error(ArgumentError)
      end
    end

    context 'with a registered scheme' do
      before do
        Rackstash::Adapters.register adapter, 'dummy'
      end

      it 'creates an adapter from the scheme' do
        raw_uri = 'dummy://example.com'
        expect(adapter).to receive(:from_uri).with(URI(raw_uri)).and_call_original
        expect(Rackstash::Adapters[raw_uri]).to be_an Rackstash::Adapters::Adapter
      end

      it 'creates an adapter from a URI' do
        uri = URI('dummy://example.com')
        expect(adapter).to receive(:from_uri).with(uri).and_call_original
        expect(Rackstash::Adapters[uri]).to be_an Rackstash::Adapters::Adapter
      end

      it 'raises if no scheme was found' do
        expect(adapter).to_not receive(:new)
        expect(adapter).to_not receive(:from_uri)
        expect { Rackstash::Adapters['unknown://example.com'] }
          .to raise_error(ArgumentError)
        expect { Rackstash::Adapters[URI('unknown://example.com')] }
          .to raise_error(ArgumentError)
      end

      context 'and a registered class' do
        before do
          Rackstash::Adapters.register adapter, Object
        end

        it 'falls though on invalid URI' do
          invalid_uri = '::'

          expect(adapter).to_not receive(:from_uri)
          # from the fallback
          expect(adapter).to receive(:new).with(invalid_uri).and_call_original
          expect(Rackstash::Adapters[invalid_uri]).to be_an Rackstash::Adapters::Adapter
        end

        it 'falls though if no scheme was found' do
          unknown_uri = 'unknown://example.com'

          expect(adapter).to_not receive(:from_uri)
          expect(adapter).to receive(:new).with(unknown_uri).and_call_original
          expect(Rackstash::Adapters[unknown_uri]).to be_an Rackstash::Adapters::Adapter
        end
      end
    end

    context 'with an existing adapter object' do
      it 'just returns the object' do
        adapter_instance = adapter.new
        Rackstash::Adapters.register adapter, Object

        expect(adapter).to_not receive(:new)
        expect(Rackstash::Adapters[adapter_instance]).to equal adapter_instance
      end
    end
  end
end
