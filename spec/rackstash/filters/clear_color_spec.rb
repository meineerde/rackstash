# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filters/clear_color'

describe Rackstash::Filters::ClearColor do
  let(:filter) { described_class.new }

  it 'removes any ANSI color codes from the message' do
    event = { 'message' => "Important\n\e[31mRED TEXT\e[0m\nOK" }
    expect(filter.call(event)).to eql 'message' => "Important\nRED TEXT\nOK"
  end

  it 'removes color codes from a message array' do
    event = {
      'message' => ["Some \e[31mred\e[0m\nand", "some \e[32mgreen\e[0m text" ]
    }
    expect(filter.call(event)).to eql 'message' => [
      "Some red\nand", "some green text"
    ]
  end

  it 'does nothing if there is no message field' do
    event = { 'foo' => 'bar' }
    expect(filter.call(event)).to eql 'foo' => 'bar'
  end

end
