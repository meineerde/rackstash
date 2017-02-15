# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/fields/array'

describe Rackstash::Fields::Array do
  let(:array) { Rackstash::Fields::Array.new }

  describe '#[]' do
    it 'returns nil if a value was not set' do
      expect(array[1]).to be_nil
    end

    it 'returns a set value' do
      array[0] = 'value'
      expect(array[0]).to eql 'value'
    end
  end

  describe '#[]=' do
    it 'normalizes values' do
      expect(array).to receive(:normalize).with('value').and_return('normalized')

      array[0] = 'value'
      expect(array[0]).to eql 'normalized'
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
      expect(array.concat(-> { [-> { :foo } ] } )).to contain_exactly 'foo'
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
