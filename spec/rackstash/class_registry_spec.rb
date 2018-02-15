# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/class_registry'

RSpec.describe Rackstash::ClassRegistry do
  let(:registry) { described_class.new('value') }
  let(:klass) { Class.new }

  describe '#initialize' do
    it 'sets the object_type' do
      expect(registry.object_type).to eql 'value'
    end
  end

  describe '#[]' do
    before do
      registry[:class] = klass
    end

    it 'returns the class for a String' do
      expect(registry['class']).to equal klass
    end

    it 'returns the class for a Symbol' do
      expect(registry[:class]).to equal klass
    end

    it 'returns an actual class' do
      expect(registry[klass]).to equal klass
      expect(registry[String]).to equal String
    end

    it 'returns nil on unknown names' do
      expect(registry[:unknown]).to be nil
      expect(registry['invalid']).to be nil
    end
  end

  describe '#fetch' do
    before do
      registry[:class] = klass
    end

    it 'returns the class for a String' do
      expect(registry.fetch('class')).to equal klass
    end

    it 'returns the class for a Symbol' do
      expect(registry.fetch(:class)).to equal klass
    end

    it 'returns an actual class' do
      expect(registry.fetch(klass)).to equal klass
      expect(registry.fetch(String)).to equal String
    end

    it 'raises a KeyError on unknown names' do
      expect { registry.fetch(:unknown) }
        .to raise_error(KeyError, 'No value was registered for :unknown')
      expect { registry.fetch('invalid') }
        .to raise_error(KeyError, 'No value was registered for "invalid"')
    end

    it 'returns the default value with unknown names' do
      expect(registry.fetch(:unknown, 'Hello World')).to eql 'Hello World'
      expect(registry.fetch('invalid', 'Hello World')).to eql 'Hello World'
    end

    it 'calls the block and returns its value with unknown names' do
      expect { |b| registry.fetch('invalid', &b) }.to yield_with_args(:invalid)
      expect(registry.fetch('invalid') { |e| e.upcase }).to eql :INVALID
    end

    it 'raises a TypeError on invalid names' do
      expect { registry.fetch(0) }
        .to raise_error(TypeError, '0 can not be used to describe value classes')
      expect { registry.fetch(nil) }
        .to raise_error(TypeError, 'nil can not be used to describe value classes')
      expect { registry.fetch(true) }
        .to raise_error(TypeError, 'true can not be used to describe value classes')
    end
  end

  describe '[]=' do
    it 'registers a class at the given name' do
      registry[:name] = klass
      registry[:alias] = klass

      expect(registry[:name]).to equal klass
      expect(registry[:alias]).to equal klass
    end

    it 'rejects invalid names' do
      expect { registry[0] = Class.new }
        .to raise_error(TypeError, 'Can not use 0 to register a value class')
      expect { registry[nil] = Class.new }
        .to raise_error(TypeError, 'Can not use nil to register a value class')
      expect { registry[String] = Class.new }
        .to raise_error(TypeError, 'Can not use String to register a value class')
    end

    it 'rejects invalid values' do
      expect { registry[:foo] = 123 }
        .to raise_error(TypeError, 'Can only register class objects')
      expect { registry[:foo] = -> { :foo } }
        .to raise_error(TypeError, 'Can only register class objects')
      expect { registry[:nil] = nil }
        .to raise_error(TypeError, 'Can only register class objects')
    end
  end

  describe '#clear' do
    it 'removes all registrations' do
      registry[:class] = klass
      expect(registry[:class]).to equal klass

      expect(registry.clear).to equal registry
      expect(registry[:class]).to be nil
    end
  end

  describe '#each' do
    it 'yield each registered pait' do
      registry['name'] = klass
      registry[:alias] = klass

      expect { |b| registry.each(&b) }
        .to yield_successive_args([:name, klass], [:alias, klass])
    end

    it 'returns the registry if a block was provided' do
      registry['name'] = klass
      expect(registry.each {}).to equal registry
    end

    it 'returns an Enumerator if no block was provided' do
      registry['name'] = klass
      expect(registry.each).to be_instance_of Enumerator
    end
  end

  describe '#freeze' do
    it 'freezes the object' do
      expect(registry.freeze).to equal registry
      expect(registry).to be_frozen
    end

    it 'denies all further changes' do
      registry.freeze
      expect { registry[:name] = klass }.to raise_error(RuntimeError)
    end
  end

  describe '#names' do
    it 'returns all registered names' do
      registry['name'] = klass
      registry[:alias] = klass

      expect(registry.names).to eql [:name, :alias]
    end
  end

  describe '#to_h' do
    it 'returns a Hash containing all registrations' do
      registry['name'] = klass
      registry[:alias] = klass

      expect(registry.to_h).to eql(name: klass, alias: klass)
    end

    it 'returns a copy of the internal data' do
      registry['name'] = klass

      hash = registry.to_h
      hash[:alias] = klass

      expect(registry[:alias]).to be nil
    end
  end
end
