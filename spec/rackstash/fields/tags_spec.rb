# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/fields/tags'

describe Rackstash::Fields::Tags do
  let(:tags) { Rackstash::Fields::Tags.new }

  describe '#<<' do
    it 'adds a single tag' do
      tags << 'tag'
      expect(tags.tagged?('tag')).to be true
    end

    it 'returns tags' do
      expect(tags << 'tag').to equal tags
    end
  end

  describe '#as_json' do
    before do
      tags.merge! [123, 'tag', true]
    end

    it 'returns a simple array' do
      expect(tags.as_json).to be_a ::Array
      expect(tags.as_json).to eql ['123', 'tag', 'true']
    end

    it 'returns a new copy each time' do
      expect(tags.as_json).to eql tags.as_json
      expect(tags.as_json).not_to equal tags.as_json
    end

    it 'can use to_ary as an alias' do
      expect(tags.to_ary).to eql tags.as_json
    end

    it 'can use to_a as an alias' do
      expect(tags.to_a).to eql tags.as_json
    end
  end

  describe '#clear' do
    it 'clears all tags' do
      tags << 'beep'
      tags.clear
      expect(tags.to_a).to be_empty
    end

    it 'returns the tags' do
      tags << 'beep'
      expect(tags.clear).to equal tags
    end
  end

  describe '#empty?' do
    it 'returns true of there are any tags' do
      expect(tags.empty?).to be true
      tags << 'foo'
      expect(tags.empty?).to be false
      tags.clear
      expect(tags.empty?).to be true
    end
  end

  describe '#merge' do
    it 'returns a new object' do
      new_tags = tags.merge ['hello']

      expect(new_tags).to be_a Rackstash::Fields::Tags
      expect(new_tags.tagged?('hello')).to be true
      expect(new_tags).not_to equal tags

      # The original hash is not changed
      expect(tags.tagged?('hello')).to be false
    end
  end

  describe '#merge!' do
    it 'merges multiple tags as strings' do
      tags.merge! ['foo', 'bar']
      expect(tags.to_a).to eql ['foo', 'bar']

      tags.merge! [123, 'foo', nil]
      expect(tags.to_a).to eql ['foo', 'bar', '123']

      expect(tags.to_a).to all be_frozen
    end

    it 'resolves procs' do
      tags.merge! [-> { 123 }]
      expect(tags.to_a).to eql ['123']

      tags.merge! [-> { self }], scope: :foo
      expect(tags.to_a).to eql ['123', 'foo']
    end

    it 'flattens arguments' do
      tags.merge! [123, [-> { ['foo', -> { 'bar' }] }]]
      expect(tags.to_a).to eql ['123', 'foo', 'bar']
    end

    it 'accepts tags' do
      new_tags = Rackstash::Fields::Tags.new
      new_tags << 'foo'

      tags.merge! [new_tags]

      expect(tags.to_a).to eql ['foo']
    end

    it 'accepts a set' do
      new_tags = Set['foo', 'bar']
      tags.merge! [new_tags]

      expect(tags.to_a).to eql ['foo', 'bar']
    end
  end

  describe '#tagged?' do
    it 'checks if the argument is tagged' do
      tags.merge! ['foo', '123']

      expect(tags.tagged?('foo')).to be true
      expect(tags.tagged?(:foo)).to be true
      expect(tags.tagged?(123)).to be true
      expect(tags.tagged?('123')).to be true

      expect(tags.tagged?(nil)).to be false
      expect(tags.tagged?('bar')).to be false
    end
  end

  describe 'to_set' do
    it 'returns a copy of the internal set' do
      expect(tags.to_set).to be_a Set

      tags.merge! ['foo', nil]

      expect(tags.to_set.include?('foo')).to be true
      expect(tags.to_set.include?(nil)).to be false
      expect(tags.to_set.include?('')).to be false
    end
  end

  describe 'Converter' do
    it 'creates a new tags list' do
      raw = [Time.now, 'foo']
      tags = Rackstash::Fields::Tags(raw)

      expect(tags).to be_a Rackstash::Fields::Tags
      expect(tags.to_a).to match [String, 'foo']
    end
  end
end
