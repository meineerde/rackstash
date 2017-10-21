# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter/rename'

describe Rackstash::Filter::Rename do
  let(:event) {
    {
      'foo' => 'foo value',
      'bar' => 'bar value'
    }
  }

  def filter!(spec)
    described_class.new(spec).call(event)
  end

  it 'renames existing fields' do
    filter!('foo' => 'awesome')
    expect(event).to eql 'awesome' => 'foo value', 'bar' => 'bar value'
  end

  it 'it ignores missing fields' do
    filter!('unknown' => 'ohnoes')
    expect(event).to eql 'foo' => 'foo value', 'bar' => 'bar value'
  end

  it 'stringifies spec values' do
    filter!(foo: :bam)
    expect(event).to eql 'bam' => 'foo value', 'bar' => 'bar value'
  end

  it 'overwrites conflicting keys' do
    filter!('foo' => 'bar')
    expect(event).to eql 'bar' => 'foo value'
  end

  it 'returns the given event object' do
    expect(filter!('bar' => 'baz')).to equal event
  end
end
