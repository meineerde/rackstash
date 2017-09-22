# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filters/replace'

describe Rackstash::Filters::Replace do
  let(:event) {
    {
      'foo' => 'foo value',
      'bar' => 'bar value'
    }
  }

  def filter!(spec)
    described_class.new(spec).call(event)
  end

  it 'sets evaluates values from callable objects' do
    filter!('foo' => ->(event) { event['foo'].upcase } )
    expect(event).to eql 'foo' => 'FOO VALUE', 'bar' => 'bar value'
  end

  it 'sets raw values' do
    filter!('bar' => 123 )
    expect(event).to eql 'foo' => 'foo value', 'bar' => 123
  end

  it 'always sets fields' do
    filter!('baz' => 42, 'boing' => ->(event) { 'quark' })
    expect(event).to eql(
      'foo' => 'foo value',
      'bar' => 'bar value',
      'baz' => 42,
      'boing' => 'quark'
    )
  end

  it 'stringifies keys' do
    filter!(foo: ->(event) { event['foo'].upcase } )
    expect(event).to eql 'foo' => 'FOO VALUE', 'bar' => 'bar value'
  end

  it 'returns the given event object' do
    expect(filter!('bar' => 'baz')).to equal event
  end
end
