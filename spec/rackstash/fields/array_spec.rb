# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/fields/array'

describe Rackstash::Fields::Array do
  let(:array) { Rackstash::Fields::Array.new }

  describe '#+' do
    it 'returns the addition of elements' do
      array[0] = 'existing'
      expect(array + ['existing', -> { 'new' }, [:nested]])
        .to contain_exactly('existing', 'existing', 'new', ['nested'])
        .and be_a(Rackstash::Fields::Array)
    end

    it 'returns a new Array' do
      expect(array + [:foo]).to be_a(Rackstash::Fields::Array)
      expect(array + [:foo]).not_to equal array
    end
  end

  describe '#-' do
    it 'returns the subtraction of elements' do
      array[0] = 'foo'
      array[1] = 'bar'
      expect(array - [-> { :bar }, ['foo']]).to contain_exactly 'foo'
    end

    it 'returns a new Array' do
      expect(array - [:foo]).to be_a(Rackstash::Fields::Array).and be_empty
      expect(array - [:foo]).not_to equal array
    end
  end

  describe '#|' do
    it 'returns the union of elements' do
      array[0] = 'existing'
      expect(array | ['new', :existing, -> { 123 }])
        .to contain_exactly 'existing', 'new', 123
    end

    it 'returns a new Array' do
      expect(array | [:foo]).to be_a(Rackstash::Fields::Array)
      expect(array | [:foo]).not_to equal array
    end
  end

  describe '#&' do
    it 'returns the intersection of elements' do
      array[0] = 'existing'
      expect(array & [:existing, 'new'])
        .to contain_exactly 'existing'
    end

    it 'returns a new Array' do
      expect(array & [:foo]).to be_a(Rackstash::Fields::Array).and be_empty
      expect(array & [:foo]).not_to equal array
    end
  end

  describe '#[]' do
    before do
      array[0] = 'value'
      array[1] = 'foo'
      array[2] = 'bar'
      array[3] = 'baz'
    end

    it 'returns a set value' do
      expect(array[0]).to eql 'value'
    end

    it 'returns an array from start, end' do
      expect(array[1, 3]).to be_a Rackstash::Fields::Array
      expect(array[1, 3].to_ary).to eql %w[foo bar baz]

      expect(array[2, 0].to_ary).to eql []
      expect(array[2, 1].to_ary).to eql %w[bar]
      expect(array[2, 5].to_ary).to eql %w[bar baz]
    end

    it 'returns an array from a range' do
      expect(array[1..3]).to be_a Rackstash::Fields::Array
      expect(array[1..3].to_ary).to eql %w[foo bar baz]

      expect(array[2..4].to_ary).to eql %w[bar baz]
      expect(array[2..-1].to_ary).to eql %w[bar baz]
    end

    it 'returns nil if a value was not set' do
      expect(array[5]).to be_nil
      expect(array[5, 2]).to be_nil
      expect(array[2, -1]).to be_nil
      expect(array[5..9]).to be_nil
    end
  end

  describe '#[]=' do
    it 'normalizes values' do
      expect(array).to receive(:normalize).with('value').and_return('normalized')

      array[0] = 'value'
      expect(array[0]).to eql 'normalized'
    end

    it 'can set values on a range' do
      array.concat(%w[hello world with flowers and unicorns])

      array[1..4] = %w[super duper]
      expect(array.as_json).to eql %w[hello super duper unicorns]
    end

    it 'can set values from start, length' do
      array.concat(%w[hello world with flowers and unicorns])

      array[1, 4] = %w[shiny and sparkling]
      expect(array.as_json).to eql %w[hello shiny and sparkling unicorns]
    end
  end

  describe '#<<' do
    it 'normalized the value' do
      expect(array).to receive(:normalize).with('value').twice.and_return('normalized')

      array << 'value'
      expect(array[0]).to eql 'normalized'
      expect(array[1]).to be nil

      array << 'value'
      expect(array[0]).to eql 'normalized'
      expect(array[1]).to eql 'normalized'
    end

    it 'can append only one value' do
      expect { array.<< 'foo', 'bar' }.to raise_error ArgumentError
    end

    it 'returns the array' do
      expect(array << 'value').to equal array
    end
  end

  describe '#as_json' do
    before do
      array[0] = 'value'
      array[1] = { 'key' => 'nested value', number: 42 }
      array[2] = ['v1', :v2]
    end

    it 'returns a simple array' do
      expect(array.as_json).to be_instance_of ::Array
      expect(array.as_json.length).to eql 3
    end

    it 'returns a nested hash' do
      expect(array[1]).to be_a Rackstash::Fields::Hash

      expect(array.as_json[1]).to be_a Hash
      expect(array.as_json[1]).to eql 'key' => 'nested value', 'number' => 42
    end

    it 'returns a nested array' do
      expect(array[2]).to be_a Rackstash::Fields::Array

      expect(array.as_json[2]).to be_instance_of ::Array
      expect(array.as_json[2]).to eql %w[v1 v2]
    end

    it 'returns a new copy each time' do
      expect(array.as_json).to eql array.as_json
      expect(array.as_json).not_to equal array.as_json

      expect(array.as_json[1]).to eql array.as_json[1]
      expect(array.as_json[1]).not_to equal array.as_json[1]

      expect(array.as_json[2]).to eql array.as_json[2]
      expect(array.as_json[2]).not_to equal array.as_json[2]
    end

    it 'can not change the raw value' do
      as_json = array.as_json
      as_json[3] = 'foo'

      expect(array[3]).to be_nil
    end

    it 'can use to_ary as an alias' do
      expect(array.to_ary).to eql array.as_json
    end

    it 'can use to_a as an alias' do
      expect(array.to_a).to eql array.as_json
    end
  end

  describe '#clear' do
    it 'clears the array' do
      array[0] = 'beep'
      array.clear
      expect(array[0]).to be_nil
    end

    it 'returns the array' do
      array[0] = 'bar'
      expect(array.clear).to equal array
    end
  end

  describe '#concat' do
    it 'contacts an array' do
      array[0] = 'first'
      ary = ['foo', 'bar']

      expect(array).to receive(:normalize).with(ary, anything).ordered.and_call_original
      expect(array).to receive(:normalize).with('foo', anything).ordered.and_call_original
      expect(array).to receive(:normalize).with('bar', anything).ordered.and_call_original

      expect(array.concat(ary)).to equal array

      expect(array[0]).to eql 'first'

      expect(array[1]).to eql 'foo'
      expect(array[1]).to be_frozen
      expect(array[2]).to eql 'bar'
      expect(array[2]).to be_frozen
    end

    it 'refuses to concat an arbitrary value' do
      expect { array.concat(:foo) }.to raise_error TypeError
      expect { array.concat(42) }.to raise_error TypeError
      expect { array.concat(false) }.to raise_error TypeError
      expect { array.concat(nil) }.to raise_error TypeError
    end

    it 'resolves nested procs' do
      expect(array.concat(-> { [-> { :foo }] })).to contain_exactly 'foo'
    end

    it 'resolves nested procs with a custom scope' do
      expect(
        array.concat(-> { [self, -> { self.to_s.upcase }] }, scope: :stuff)
      ).to contain_exactly 'stuff', 'STUFF'
    end
  end

  describe '#empty?' do
    it 'returns true of there are any tags' do
      expect(array.empty?).to be true
      array[0] = 'foo'
      expect(array.empty?).to be false
      array.clear
      expect(array.empty?).to be true
    end
  end

  describe '#length' do
    it 'returns the length of the array' do
      expect(array.length).to eql 0

      array[0] = 'first'
      expect(array.length).to eql 1

      array.clear
      expect(array.length).to eql 0
    end

    it 'can use size as an alias' do
      expect(array.size).to eql 0
      array[0] = 'first'
      expect(array.size).to eql 1
    end
  end

  describe '#merge' do
    it 'returns the union of elements' do
      array[0] = 'existing'
      expect(array.merge(['new', :existing, -> { 123 }]))
        .to contain_exactly('existing', 'new', 123)
        .and be_a(Rackstash::Fields::Array)
    end

    it 'returns a new Array' do
      expect(array.merge([:foo])).to be_a(Rackstash::Fields::Array)
      expect(array.merge([:foo])).not_to equal array
    end

    it 'resolves nested procs with a custom scope' do
      expect(
        array.merge(-> { [self, -> { self.to_s.upcase }] }, scope: :stuff)
      ).to contain_exactly 'stuff', 'STUFF'
    end
  end

  describe '#merge!' do
    it 'sets the union of elements to self' do
      array[0] = 'existing'
      expect(array.merge!(['new', :existing, -> { 123 }]))
        .to contain_exactly 'existing', 'new', 123
    end

    it 'returns self' do
      expect(array.merge!([:foo])).to equal array
    end

    it 'resolves nested procs with a custom scope' do
      expect(
        array.merge!(-> { [self, -> { self.to_s.upcase }] }, scope: :stuff)
      ).to contain_exactly 'stuff', 'STUFF'
    end
  end

  describe '#pop' do
    it 'returns nothing from an empty array' do
      expect(array.pop).to be_nil
      expect(array.pop(42)).to be_instance_of(Array).and be_empty
    end

    it 'returns and removes the last element' do
      array << 'foo' << 'bar'

      expect(array.pop).to eql 'bar'
      expect(array[0]).to eql 'foo'
    end

    it 'returns and removes at most n elements' do
      array << 'foo' << 'bar' << 'baz'

      expect(array.pop(2)).to eql ['bar', 'baz']
      expect(array[0]).to eql 'foo'
    end
  end

  describe '#push' do
    it 'can append multiple values' do
      expect(array.push 'value', 'value2').to equal array
      expect(array[0]).to eql 'value'
      expect(array[1]).to eql 'value2'
    end

    it 'appends arrays as is' do
      value = ['hello']
      array.push value

      expect(array[0]).to be_a Rackstash::Fields::Array
      expect(array[0].to_a).to eql value
    end

    it 'can use append as an alias' do
      expect(array.append 'foo').to equal array
      expect(array[0]).to eql 'foo'
    end
  end

  describe '#unshift' do
    it 'prepends objects' do
      array[0] = 'first'
      array.unshift('foo', 'bar')

      expect(array[0]).to eql 'foo'
      expect(array[1]).to eql 'bar'
      expect(array[2]).to eql 'first'
    end

    it 'normalizes values with the scope' do
      array.unshift -> { self + 3 }, scope: 2
      expect(array[0]).to eql 5
    end
  end

  describe '#shift' do
    before do
      array[0] = 'value'
      array[1] = 'foo'
      array[2] = 'bar'
      array[3] = 'baz'
    end

    it 'shift a single value' do
      expect(array.shift).to eql 'value'
      expect(array[0]).to eql 'foo'
    end

    it 'shift multiple values' do
      expect(array.shift(3))
        .to be_instance_of(described_class)
        .and contain_exactly('value', 'foo', 'bar')
      expect(array[0]).to eql 'baz'
    end
  end

  describe 'Converter' do
    it 'creates a new array' do
      raw = [Time.now, 'foo']
      array = Rackstash::Fields::Array(raw)

      expect(array).to be_a Rackstash::Fields::Array
      expect(array[0]).to be_a String
      expect(array[1]).to eql 'foo'
    end
  end
end
