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

      expect(hash.forbidden_keys)
        .to be_a(Set)
        .and be_frozen
        .and all(
          be_frozen.and be_a String
        )
    end

    it 'accepts forbidden_keys as a Set' do
      forbidden_keys = Set['field']
      hash = Rackstash::Fields::Hash.new(forbidden_keys: forbidden_keys)

      expect(hash.forbidden_keys)
        .to be_a(Set)
        .and be_frozen
        .and all(
          be_frozen.and be_a String
        )

      # We create a new set without affecting the passed one
      expect(hash.forbidden_keys).not_to equal forbidden_keys
    end

    it 'accepts forbidden_keys as a frozen Set' do
      forbidden_keys = Set['field'.freeze].freeze
      hash = Rackstash::Fields::Hash.new(forbidden_keys: forbidden_keys)

      expect(hash.forbidden_keys).to equal forbidden_keys
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

        expect { hash[:foo] = 'value' }.to raise_error ArgumentError
        expect { hash['foo'] = 'value' }.to raise_error ArgumentError
        expect { hash[42] = 'value' }.to raise_error ArgumentError
        expect { hash['42'] = 'value' }.to raise_error ArgumentError
        expect { hash[:'42'] = 'value' }.to raise_error ArgumentError
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
      expect(hash.as_json).to be_instance_of ::Hash
      expect(hash.as_json.keys).to eql %w[simple hash array]
    end

    it 'returns a nested hash' do
      expect(hash['hash']).to be_instance_of Rackstash::Fields::Hash

      expect(hash.as_json['hash']).to be_instance_of Hash
      expect(hash.as_json['hash']).to eql 'key' => 'nested value', 'number' => 42
    end

    it 'returns a nested array' do
      expect(hash['array']).to be_instance_of Rackstash::Fields::Array

      expect(hash.as_json['array']).to be_instance_of ::Array
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

  describe '#deep_merge' do
    # This works almost exactly the same as deep_merge! although we don't repeat
    # all of the tests here
    it 'calls merge' do
      value = { hello: -> { self } }
      scope = 'world'

      expect(hash).to receive(:merge).with(value, force: false, scope: scope)
        .and_call_original
      new_hash = hash.deep_merge(value, force: false, scope: scope)
      expect(new_hash).to have_key 'hello'
    end

    it 'returns a new Hash' do
      hash['foo'] = ['bar']

      new_hash = hash.deep_merge('beep' => :boop, 'foo' => [123])
      expect(new_hash).to be_a Rackstash::Fields::Hash

      expect(hash).not_to have_key 'beep'
      expect(hash['foo']).to contain_exactly 'bar'

      expect(new_hash).not_to equal hash
      expect(new_hash).to include 'beep', 'foo'
      expect(new_hash['foo']).to contain_exactly 'bar', 123
    end
  end

  describe '#deep_merge!' do
    let(:forbidden_keys) { ['forbidden'] }

    it 'calls merge!' do
      value = { hello: -> { self } }
      scope = 'world'

      expect(hash).to receive(:merge!).with(value, force: false, scope: scope)
        .and_call_original
      hash.deep_merge!(value, force: false, scope: scope)
      expect(hash).to have_key 'hello'
    end

    it 'returns self' do
      expect(hash.deep_merge!(foo: :bar)).to equal hash
    end

    it 'rejects not hash-convertible arguments' do
      expect { hash.deep_merge!(nil) }.to raise_error TypeError
      expect { hash.deep_merge!(false) }.to raise_error TypeError
      expect { hash.deep_merge!(true) }.to raise_error TypeError
      expect { hash.deep_merge!(123) }.to raise_error TypeError
      expect { hash.deep_merge!(:foo) }.to raise_error TypeError
      expect { hash.deep_merge!('foo') }.to raise_error TypeError
      expect { hash.deep_merge!([]) }.to raise_error TypeError
      expect { hash.deep_merge!(['foo']) }.to raise_error TypeError

      expect { hash.deep_merge!(-> { 3 }) }.to raise_error TypeError
      expect { hash.deep_merge!(-> { 'foo' }) }.to raise_error TypeError
      expect { hash.deep_merge!(-> { ['foo'] }) }.to raise_error TypeError
    end

    context 'with force: true' do
      it 'adds fields, overwriting existing ones' do
        hash['foo'] = 'original'
        hash.deep_merge!('foo' => 'overwritten', 'bar' => 'some value')

        expect(hash.keys).to contain_exactly 'foo', 'bar'
        expect(hash['foo']).to eql 'overwritten'
        expect(hash['bar']).to eql 'some value'
      end

      it 'merges nested hashes, overwriting existing nested values' do
        hash['key'] = { 'foo' => 'bar' }

        hash.deep_merge! 'key' => { foo: 'fizz', baz: 'qux' }
        expect(hash['key'].as_json).to eql 'foo' => 'fizz', 'baz' => 'qux'
      end

      it 'overwrites nested values unless types match' do
        hash['key'] = { nested_key: 'value' }

        hash.deep_merge! 'key' => [:foo, 'baz']
        expect(hash['key'])
          .to be_a(Rackstash::Fields::Array)
          .and contain_exactly 'foo', 'baz'

        hash.deep_merge! 'key' => 123
        expect(hash['key']).to eql 123
      end

      it 'raises an error when trying to merge forbidden fields' do
        expect { hash.deep_merge!({ forbidden: 'value' }, force: true) }
          .to raise_error ArgumentError
        expect { hash.deep_merge!({ 'forbidden' => 'value' }, force: true) }
          .to raise_error ArgumentError
        expect(hash).to_not have_key 'forbidden'
      end

      it 'allows to merge forbidden fields in nested hashes' do
        hash.deep_merge!({ top: { 'forbidden' => 'value' } }, force: true)
        expect(hash['top'])
          .to be_a(Rackstash::Fields::Hash)
          .and have_key 'forbidden'
      end
    end

    context 'with force: false' do
      it 'adds fields, ignoring existing ones' do
        hash['foo'] = 'original'
        hash.deep_merge!({ 'foo' => 'ignored', 'bar' => 'some value' }, force: false)

        expect(hash.keys).to contain_exactly 'foo', 'bar'
        expect(hash['foo']).to eql 'original'
        expect(hash['bar']).to eql 'some value'
      end

      it 'merges nested hashes, ignoring existing nested values' do
        hash['key'] = { 'foo' => 'bar' }
        expect(hash['key'].as_json).to eql 'foo' => 'bar'

        hash.deep_merge!({ 'key' => { foo: 'fizz', baz: 'qux' } }, force: false)
        expect(hash['key'].as_json).to eql 'foo' => 'bar', 'baz' => 'qux'
      end

      it 'ignores nested values unless types match' do
        hash['key'] = { nested_key: 'value' }

        hash.deep_merge!({ 'key' => [:foo, 'baz'] }, force: false)
        expect(hash['key'])
          .to be_a(Rackstash::Fields::Hash)
          .and have_key 'nested_key'

        hash.deep_merge!({ 'key' => 123 }, force: false)
        expect(hash['key'])
          .to be_a(Rackstash::Fields::Hash)
          .and have_key 'nested_key'
      end

      it 'overwrites nil' do
        hash['key'] = nil
        expect(hash).to have_key 'key'

        hash.deep_merge!({ 'key' => { nested: 'value' } }, force: false)
        expect(hash['key']).to be_a Rackstash::Fields::Hash
      end

      it 'ignores forbidden fields' do
        expect { hash.deep_merge!({ forbidden: 'value' }, force: false) }
          .not_to raise_error
        expect { hash.deep_merge!({ 'forbidden' => 'value' }, force: false) }
          .not_to raise_error
        expect(hash).to_not have_key 'forbidden'
      end

      it 'allows to merge forbidden fields in nested hashes' do
        hash.deep_merge!({ top: { 'forbidden' => 'value' } }, force: false)
        expect(hash['top'])
          .to be_a(Rackstash::Fields::Hash)
          .and have_key 'forbidden'
      end
    end

    it 'normalizes string-like array elements to strings' do
      hash.deep_merge! 'key' => [:foo, [123, 'bar'], [:qux, { fizz: [:buzz, 42] }]]
      expect(hash['key'].as_json)
        .to eql ['foo', [123, 'bar'], ['qux', { 'fizz' => ['buzz', 42] }]]

      hash.deep_merge! 'key' => ['foo', :baz, [123, :bar]]
      expect(hash['key'].as_json)
        .to eql ['foo', [123, 'bar'], ['qux', { 'fizz' => ['buzz', 42] }], 'baz']
    end

    it 'resolves conflicting values with the passed block' do
      hash['key'] = 'value'
      hash.deep_merge!('key' => 'new') { |key, old_val, new_val| [old_val, new_val] }

      expect(hash['key'].as_json).to eql ['value', 'new']
    end

    it 'always merges compatible hashes' do
      hash['key'] = { 'deep' => 'value' }
      hash.deep_merge!(
        'key' => { 'deep' => 'stuff', 'new' => 'things' }
      ) { |key, old_val, new_val| old_val + new_val }

      expect(hash['key'].as_json).to eql 'deep' => 'valuestuff', 'new' => 'things'
    end

    it 'always merges compatible arrays' do
      hash['key'] = { 'deep' => 'value', 'array' => ['v1'] }
      hash.deep_merge!(
        'key' => { 'deep' => 'stuff', 'array' => ['v2'] }
      ) { |key, old_val, new_val| old_val + new_val }

      expect(hash['key'].as_json).to eql 'deep' => 'valuestuff', 'array' => ['v1', 'v2']
    end

    it 'uses the scope to resolve values returned by the block' do
      hash['key'] = 'value'
      hash.deep_merge!({'key' => 'new'}, scope: 123) { |_key, _old, _new| -> { self } }

      expect(hash['key']).to eql 123
    end
  end

  describe '#empty?' do
    it 'returns true of there are any fields' do
      expect(hash.empty?).to be true
      hash['key'] = 'foo'
      expect(hash.empty?).to be false
      hash.clear
      expect(hash.empty?).to be true
    end
  end

  describe '#forbidden_key?' do
    let(:forbidden_keys) { ['forbidden', :foo] }

    it 'checks if a key is forbidden' do
      expect(hash.forbidden_key?('forbidden')).to be true
      expect(hash.forbidden_key?('foo')).to be true
    end
  end

  describe '#key?' do
    it 'checks whether a key was set' do
      hash['hello'] = 'World'
      expect(hash.key?('hello')).to be true
      expect(hash.key?('Hello')).to be false
      expect(hash.key?('goodbye')).to be false
    end

    it 'checks keys with stringified names' do
      hash['hello'] = 'World'
      expect(hash.key?('hello')).to be true
      expect(hash.key?(:hello)).to be true
    end

    it 'can use the alias #has_key?' do
      hash['hello'] = 'World'
      expect(hash.has_key?('hello')).to be true
      expect(hash.has_key?('goodbye')).to be false

      # We can also use the rspec matcher
      expect(hash).to have_key 'hello'
    end

    it 'can use the alias #include?' do
      hash['hello'] = 'World'
      expect(hash.include?('hello')).to be true
      expect(hash.include?('goodbye')).to be false

      # We can also use the rspec matcher
      expect(hash).to include 'hello'
    end

    it 'can use the alias #member?' do
      hash['hello'] = 'World'
      expect(hash.member?('hello')).to be true
      expect(hash.member?('goodbye')).to be false
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
      to_merge = { foo: :bar }
      expect(hash).to receive(:normalize).with(to_merge, anything).ordered.and_call_original
      expect(hash).to receive(:normalize).with(:bar, anything).ordered.and_call_original

      original_hash = hash
      # the hash is mutated in place and returned
      expect(hash.merge!(to_merge)).to equal original_hash
      expect(hash['foo']).to eql 'bar'
      expect(hash['foo']).to be_frozen
    end

    context 'with force: true' do
      it 'overwrites existing fields' do
        hash['foo'] = 'bar'

        hash.merge!({ foo: 42 }, force: true)
        expect(hash['foo']).to eql 42
      end
    end

    context 'with force: false' do
      it 'keeps existing values' do
        hash['foo'] = 'bar'

        hash.merge!({ foo: 'value' }, force: false)
        expect(hash['foo']).to eql 'bar'
      end

      it 'overwrites nil values' do
        hash['foo'] = nil
        expect(hash['foo']).to be_nil

        hash.merge!({ foo: 'value' }, force: false)
        expect(hash['foo']).to eql 'value'
      end
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

      expect(new_hash).to be_instance_of Rackstash::Fields::Hash
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

      it 'sets the original forbidden_keys on the new hash' do
        new_hash = hash.merge({ 'forbidden' => 'ignored' }, force: false)
        expect { new_hash.merge(forbidden: 'error') }.to raise_error ArgumentError
      end
    end
  end

  describe '#reverse_merge' do
    before do
      hash['foo'] = 'bar'
    end

    it 'creates a new hash' do
      expect(hash.reverse_merge(foo: :baz, beep: :boop)).not_to equal hash
      expect(hash).not_to include 'beep'
    end

    it 'does not overwrite existing values' do
      expect(hash.reverse_merge(foo: :baz, beep: :boop)['foo']).to eql 'bar'
    end

    it 'adds new values' do
      expect(hash.reverse_merge(foo: :baz, beep: :boop)['beep']).to eql 'boop'
    end

    it 'evaluates procs' do
      expect(hash.reverse_merge(-> { { beep: -> { self } } }, scope: 42)['beep'])
        .to eql 42
    end

    it 'overwrites nil values' do
      hash['beep'] = nil
      expect(hash).to include 'beep'

      expect(hash.reverse_merge(beep: :boop)['beep']).to eql 'boop'
    end

    it 'raises an error for non-hash arguments' do
      expect { hash.reverse_merge [] }.to raise_error TypeError
      expect { hash.reverse_merge nil }.to raise_error TypeError
      expect { hash.reverse_merge false }.to raise_error TypeError
      expect { hash.reverse_merge 'value' }.to raise_error TypeError
    end
  end

  describe '#reverse_merge!' do
    before do
      hash['foo'] = 'bar'
    end

    it 'mutates the existing hash' do
      expect(hash.reverse_merge!(foo: :baz, beep: :boop)).to equal hash
      expect(hash).to include 'beep'
    end

    it 'does not overwrite existing values' do
      expect(hash.reverse_merge!(foo: :baz, beep: :boop)['foo']).to eql 'bar'
    end

    it 'adds new values' do
      expect(hash.reverse_merge!(foo: :baz, beep: :boop)['beep']).to eql 'boop'
    end

    it 'evaluates procs' do
      expect(hash.reverse_merge!(-> { { beep: -> { self } } }, scope: 42)['beep'])
        .to eql 42
    end

    it 'overwrites nil values' do
      hash['beep'] = nil
      expect(hash).to include 'beep'

      expect(hash.reverse_merge!(beep: :boop)['beep']).to eql 'boop'
    end

    it 'raises an error for non-hash arguments' do
      expect { hash.reverse_merge! [] }.to raise_error TypeError
      expect { hash.reverse_merge! nil }.to raise_error TypeError
      expect { hash.reverse_merge! false }.to raise_error TypeError
      expect { hash.reverse_merge! 'value' }.to raise_error TypeError
    end
  end

  describe '#set' do
    it 'allows to set a normalized value' do
      expect(hash).to receive(:normalize).with(:value).and_call_original

      hash.set(:symbol) { :value }

      expect(hash['symbol']).to eql 'value'
    end

    it 'ignores forbidden keys' do
      forbidden_keys << 'forbidden'

      expect { |b| hash.set(:forbidden, &b) }.not_to yield_control
      expect { |b| hash.set('forbidden', &b) }.not_to yield_control

      expect(hash['forbidden']).to be_nil
    end

    it 'ignores existing keys' do
      hash['key'] = 'value'

      expect { |b| hash.set(:key, &b) }.not_to yield_control
      expect { |b| hash.set('key', &b) }.not_to yield_control

      expect(hash['key']).to eql 'value'
    end

    it 'overwrites nil value' do
      hash['nil'] = nil
      expect { |b| hash.set('nil', &b) }.to yield_control
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

      expect(hash).to be_instance_of Rackstash::Fields::Hash
      expect(hash['time']).to be_a String
      expect(hash['string']).to eql 'foo'
    end

    it 'can specify forbidden_keys' do
      raw = { foo: :bar, forbidden: 'ignored' }
      expect { Rackstash::Fields::Hash(raw, forbidden_fields: ['forbidden']) }
        .to raise_error ArgumentError
    end
  end
end
