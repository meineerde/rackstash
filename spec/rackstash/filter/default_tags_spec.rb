# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter/default_tags'

RSpec.describe Rackstash::Filter::DefaultTags do
  let(:event) {
    {
      'key' => 'value'
    }
  }

  def filter!(*default_tags)
    described_class.new(*default_tags).call(event)
  end

  it 'adds missing tags' do
    filter! 'foo', 'bar'
    expect(event['tags']).to eql ['foo', 'bar']
  end

  it 'retains existing tags' do
    event['tags'] = ['tag']
    filter! 'foo', 'bar'

    expect(event['tags']).to eql ['tag', 'foo', 'bar']
  end

  it 'flattens and normalizes tags' do
    event['tags'] = 'bare'
    filter! [:foo, [[123]]]

    expect(event['tags']).to eql ['bare', 'foo', '123']
  end

  it 'resolves Procs' do
    filter! -> { ['beep', -> { ['boop'] }] }

    expect(event['tags']).to eql ['beep', 'boop']
  end
end
