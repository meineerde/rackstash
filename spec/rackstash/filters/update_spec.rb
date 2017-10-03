# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filters/update'

describe Rackstash::Filters::Update do
  let(:event) {
    {
      'foo' => 'foo value',
      'bar' => 'bar value'
    }
  }

  def filter!(spec)
    described_class.new(spec).call(event)
  end

  it 'sets evaluated values from callable objects' do
    filter!('foo' => ->(event) { event['foo'].upcase })
    expect(event).to eql 'foo' => 'FOO VALUE', 'bar' => 'bar value'
  end

  it 'sets raw values' do
    filter!('bar' => 123)
    expect(event).to eql 'foo' => 'foo value', 'bar' => 123
  end

  it 'ignores missing fields' do
    spec = { 'baz' => 42, 'boing' => ->(_event) { 'quark' } }
    expect(spec['boing']).not_to receive(:call)

    filter!(spec)
    expect(event).to eql(
      'foo' => 'foo value',
      'bar' => 'bar value'
    )
  end

  it 'stringifies keys' do
    filter!(foo: ->(event) { event['foo'].upcase })
    expect(event).to eql 'foo' => 'FOO VALUE', 'bar' => 'bar value'
  end

  it 'returns the given event object' do
    expect(filter!('bar' => 'baz')).to equal event
  end
end
