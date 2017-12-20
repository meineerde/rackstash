# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter/drop_if'

describe Rackstash::Filter::DropIf do
  describe '#initialize' do
    it 'expects a condition' do
      expect { described_class.new }.to raise_error ArgumentError
    end

    it 'accepts a callable object' do
      expect { described_class.new(->(event) {}) }.not_to raise_error
    end

    it 'accepts a block' do
      expect { described_class.new {} }.not_to raise_error
    end
  end

  describe '#call' do
    it 'returns the event if the condition is falsey' do
      event = { 'foo' => 'bar' }

      expect(described_class.new(->(_event) { false }).call(event)).to equal event
      expect(described_class.new(->(_event) { nil }).call(event)).to equal event
      expect(described_class.new { |_event| false }.call(event)).to equal event
      expect(described_class.new { |_event| nil }.call(event)).to equal event
    end

    it 'returns false if the condition is truethy' do
      event = { 'foo' => 'bar' }

      expect(described_class.new(->(_event) { true }).call(event)).to be false
      expect(described_class.new(->(_event) { event }).call(event)).to be false
      expect(described_class.new { |_event| true }.call(event)).to be false
      expect(described_class.new { |_event| event }.call(event)).to be false
    end
  end
end