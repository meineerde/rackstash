# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filters/default_fields'

describe Rackstash::Filters::DefaultFields do
  let(:event) {
    {
      'foo' => 'v1',
      'bar' => 'v2'
    }
  }

  def filter!(default_fields)
    described_class.new(default_fields).call(event)
  end

  it 'adds missing normalized fields' do
    filter! 'new' => 'boing', 123 => :number

    expect(event).to eql(
      'foo' => 'v1',
      'bar' => 'v2',
      'new' => 'boing',
      '123' => 'number'
    )
  end

  it 'retains existing fields' do
    filter! foo: 'ignored'

    expect(event).to eql(
      'foo' => 'v1',
      'bar' => 'v2'
    )
  end

  it 'deep_merges fields' do
    event['deep'] = { 'key' => [42, { 'foo' => 'bar' }, nil], 'new' => nil }
    filter! 'deep' => { key: [123], new: 'new' }

    expect(event).to eql(
      'foo' => 'v1',
      'bar' => 'v2',
      'deep' => {
        'key' => [42, { 'foo' => 'bar' }, nil, 123],
        'new' => 'new'
      }
    )
  end

  it 'resolves Procs' do
    filter! -> { { 'beep' => -> { 'boop' } } }

    expect(event).to eql(
      'foo' => 'v1',
      'bar' => 'v2',
      'beep' => 'boop'
    )
  end
end
