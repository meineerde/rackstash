# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/fields/hash'

describe Rackstash::Fields::Hash do
  let(:forbidden_keys) { Set.new }
  let(:hash) { Rackstash::Fields::Hash.new(forbidden_keys: forbidden_keys) }

  describe '#initialize' do
    it 'can be initialized without any arguments' do
      Rackstash::Fields::Hash.new
    end

    it 'accepts forbidden_keys as an Array' do
      hash = Rackstash::Fields::Hash.new(forbidden_keys: ['field'])
      expect(hash.instance_variable_get('@forbidden_keys')).to be_a Set
    end

    it 'accepts forbidden_keys as a Set' do
      hash = Rackstash::Fields::Hash.new(forbidden_keys: Set['field'])
      expect(hash.instance_variable_get('@forbidden_keys')).to be_a Set
    end
  end

  describe 'subscript accessors' do
    it 'normalizes keys when setting values' do
      hash[:foo] = 'foo value'
      expect(hash['foo']).to eql 'foo value'

      hash[42] = '42 value'
      expect(hash['42']).to eql '42 value'

      hash[nil] = 'nil value'
      expect(hash['']).to eql 'nil value'
    end

    it 'normalizes keys when accessing values' do
      hash['foo'] = 'foo value'
      expect(hash[:foo]).to eql 'foo value'

      hash['42'] = '42 value'
      expect(hash[42]).to eql '42 value'

      hash[''] = 'nil value'
      expect(hash[nil]).to eql 'nil value'
    end

    it 'returns nil if a value was not set' do
      expect(hash['missing']).to be_nil
    end

    it 'normalizes values' do
      value = 'value'
      expect(hash).to receive(:normalize).with(value).and_return('normalized')

      hash['key'] = value
      expect(hash['key']).to eql 'normalized'
    end

    it 'can use #store as an alias to #[]=' do
      hash.store 'key', 'value'
      expect(hash['key']).to eql 'value'
    end

    context 'with forbidden fields' do
      let(:forbidden_keys) { ['forbidden', :foo, 42] }

      it 'denies setting a forbidden field' do
        expect { hash[:forbidden] = 'value' }.to raise_error ArgumentError
        expect { hash['forbidden'] = 'value' }.to raise_error ArgumentError
      end

      it 'ignores non string-values in forbidden_keys' do
        expect { hash[:foo] = 'value' }.not_to raise_error
        expect { hash['foo'] = 'value' }.not_to raise_error
        expect { hash[42] = 'value' }.not_to raise_error
        expect { hash['42'] = 'value' }.not_to raise_error
        expect { hash[:'42'] = 'value' }.not_to raise_error
      end

      it 'returns nil when accessing forbidden fields' do
        expect(hash['forbidden']).to be_nil

        expect(hash[:foo]).to be_nil
        expect(hash['foo']).to be_nil
      end
    end
  end

  describe '#as_json' do
    before do
      hash['simple'] = 'value'
      hash['hash'] = { 'key' => 'nested value', number: 42 }
      hash['array'] = ['v1', :v2]
    end

    it 'returns a simple hash' do
      expect(hash.as_json).to be_a ::Hash
      expect(hash.as_json.keys).to eql %w[simple hash array]
    end

    it 'returns a nested hash' do
      expect(hash['hash']).to be_a Rackstash::Fields::Hash

      expect(hash.as_json['hash']).to be_a Hash
      expect(hash.as_json['hash']).to eql 'key' => 'nested value', 'number' => 42
    end

    it 'returns a nested array' do
      expect(hash['array']).to be_a Rackstash::Fields::Array

      expect(hash.as_json['array']).to be_an ::Array
      expect(hash.as_json['array']).to eql %w[v1 v2]
    end

    it 'returns a new copy each time' do
      expect(hash.as_json).to eql hash.as_json
      expect(hash.as_json).not_to equal hash.as_json

      expect(hash.as_json['hash']).to eql hash.as_json['hash']
      expect(hash.as_json['hash']).not_to equal hash.as_json['hash']

      expect(hash.as_json['array']).to eql hash.as_json['array']
      expect(hash.as_json['array']).not_to equal hash.as_json['array']
    end

    it 'can not change the raw value' do
      as_json = hash.as_json
      as_json['injected'] = 'foo'

      expect(hash['injected']).to be_nil
      expect(hash.keys).not_to include 'injected'
    end

    it 'can use to_hash as an alias' do
      expect(hash.to_hash).to eql hash.as_json
    end

    it 'can use to_h as an alias' do
      expect(hash.to_h).to eql hash.as_json
    end
  end

  describe '#clear' do
    it 'clears the hash' do
      hash['foo'] = 'bar'
      hash.clear
      expect(hash['foo']).to be_nil
      expect(hash.keys).to be_empty
    end

    it 'returns the hash' do
      hash['foo'] = 'bar'
      expect(hash.clear).to equal hash
    end
  end

  describe '#forbidden_key?' do
    let(:forbidden_keys) { ['forbidden', :foo] }

    it 'checks if a key is forbidden' do
      expect(hash.forbidden_key?('forbidden')).to be true
      expect(hash.forbidden_key?('foo')).to be false
    end

  end

  describe '#keys' do
    it 'returns an array of keys' do
      hash['foo'] = 'bar'
      hash[:symbol] = 'symbol'
      hash[42] = 'number'

      expect(hash.keys).to eql ['foo', 'symbol', '42']
      expect(hash.keys).to all be_frozen
    end

    it 'returns a new array each time' do
      expect(hash.keys).not_to equal hash.keys
    end
  end

  describe '#merge!' do
    it 'rejects not hash-convertible arguments' do
      expect { hash.merge!(nil) }.to raise_error TypeError
      expect { hash.merge!(false) }.to raise_error TypeError
      expect { hash.merge!(true) }.to raise_error TypeError
      expect { hash.merge!(123) }.to raise_error TypeError
      expect { hash.merge!(:foo) }.to raise_error TypeError
      expect { hash.merge!('foo') }.to raise_error TypeError
      expect { hash.merge!([]) }.to raise_error TypeError
      expect { hash.merge!(['foo']) }.to raise_error TypeError
    end

    it 'merges an empty hash with compatible arguments' do
      empty_hash = Rackstash::Fields::Hash.new

      expect(hash.merge!({})).to eql empty_hash
      expect(hash.merge!(Rackstash::Fields::Hash.new)).to eql empty_hash
    end

    it 'merges a normalized hash' do
      to_merge = {foo: :bar}
      expect(hash).to receive(:normalize).with(to_merge, anything).ordered.and_call_original
      expect(hash).to receive(:normalize).with(:bar, anything).ordered.and_call_original

      original_hash = hash
      # the hash is mutated in place and returned
      expect(hash.merge!(to_merge)).to equal original_hash
      expect(hash['foo']).to eql 'bar'
      expect(hash['foo']).to be_frozen
    end

    it 'overwrites existing fields' do
      hash['foo'] = 'bar'

      hash.merge!({ foo: 42 }, force: true)
      expect(hash['foo']).to eql 42

      hash.merge!({ foo: 'value' }, force: false)
      expect(hash['foo']).to eql 'value'
    end

    it 'calls the block on merge conflicts' do
      hash['foo'] = 'bar'

      yielded_args = []
      yielded_count = 0

      expect(hash).to receive(:normalize).with({ foo: 42 }, anything).ordered.and_call_original
      expect(hash).to receive(:normalize).with(42, anything).ordered.and_call_original
      expect(hash).to receive(:normalize).with(:symbol, anything).ordered.and_call_original

      hash.merge!(foo: 42) { |key, old_value, new_value|
        yielded_count += 1
        yielded_args = [key, old_value, new_value]
        :symbol
      }

      expect(hash['foo']).to eql 'symbol'
      expect(yielded_count).to eql 1
      expect(yielded_args).to eql ['foo', 'bar', 42]
    end

    it 'resolves the value with the passed scope' do
      scope = 'hello world'

      hash.merge!(-> { { key: self } }, scope: scope)
      expect(hash['key']).to eql 'hello world'

      hash.merge!({ key: -> { { nested: self } } }, scope: scope)
      expect(hash['key']['nested']).to eql 'hello world'
    end

    context 'with forbidden_keys' do
      let(:forbidden_keys) { ['forbidden'] }

      it 'raises an error when trying to merge forbidden_keys' do
        expect { hash.merge!('forbidden' => 'v') }.to raise_error ArgumentError
        expect { hash.merge!(forbidden: 'v') }.to raise_error ArgumentError

        expect { hash.merge!({ 'forbidden' => 'value' }, force: true) }
          .to raise_error ArgumentError
        expect { hash.merge!({ forbidden: 'value' }, force: true) }
          .to raise_error ArgumentError
      end

      it 'ignores forbidden_keys when not forcing' do
        hash.merge!({ 'forbidden' => 'ignored' }, force: false)
        expect(hash['forbidden']).to be_nil
      end
    end
  end

  describe '#merge' do
    it 'returns a new object' do
      new_hash = hash.merge(foo: :bar)

      expect(new_hash).to be_a Rackstash::Fields::Hash
      expect(new_hash).not_to equal hash

      # The origiginal hash is not changed
      expect(hash['foo']).to be_nil
    end

    describe 'with forbidden_keys' do
      let(:forbidden_keys) { ['forbidden'] }

      it 'raises an error when trying to merge forbidden_keys' do
        expect { hash.merge('forbidden' => 'v') }.to raise_error ArgumentError
      end

      it 'ignores forbidden_keys when not forcing' do
        new_hash = hash.merge({ 'forbidden' => 'ignored' }, force: false)
        expect(new_hash['forbidden']).to be_nil
      end

      it 'keeps the forbidden_keys on the new hash' do
        new_hash = hash.merge({ 'forbidden' => 'ignored' }, force: false)
        expect { new_hash.merge(forbidden: 'error') }.to raise_error ArgumentError
      end
    end
  end

  describe '#values' do
    it 'returns an array of values' do
      hash['string'] = 'beep'
      hash['float'] = 1.2
      hash['number'] = 42

      expect(hash.values).to eql ['beep', 1.2, 42]
      expect(hash.values).to all be_frozen
    end

    it 'returns a new array each time' do
      expect(hash.values).not_to equal hash.values
    end
  end

  describe 'Converter' do
    it 'creates a new Hash' do
      raw = { :time => Time.now, 'string' => 'foo' }
      hash = Rackstash::Fields::Hash(raw)

      expect(hash).to be_a Rackstash::Fields::Hash
      expect(hash['time']).to be_a String
      expect(hash['string']).to eql 'foo'
    end

    it 'can specify forbidden_keys' do
      raw = { foo: :bar, forbidden: 'ignored' }
      expect { Rackstash::Fields::Hash(raw, forbidden_fields: ['forbidden']) }.to raise_error ArgumentError
    end
  end
end
