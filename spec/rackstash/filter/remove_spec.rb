# frozen_string_literal: true
#
# Copyright 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter/remove'

RSpec.describe Rackstash::Filter::Remove do
  let(:event) {
    {
      'foo' => 'foo value',
      'bar' => 'bar value'
    }
  }

  def filter!(*spec, &block)
    described_class.new(*spec, &block).call(event)
  end

  it 'removes existing fields' do
    filter!('foo')
    expect(event).to eql 'bar' => 'bar value'
  end

  it 'it ignores missing fields' do
    filter!('unknown', 'bar')
    expect(event).to eql 'foo' => 'foo value'
  end

  it 'stringifies spec values' do
    filter!(:foo)
    expect(event).to eql 'bar' => 'bar value'
  end

  it 'removes fields matched by a regular expression' do
    filter!(/f/, /blar/)
    expect(event).to eql 'bar' => 'bar value'
  end

  it 'removes fields matched by a Proc' do
    filter!(->(key) { key.start_with?('b') })
    expect(event).to eql 'foo' => 'foo value'
  end

  it 'returns the given event object' do
    expect(filter!('bar')).to equal event
  end
end
