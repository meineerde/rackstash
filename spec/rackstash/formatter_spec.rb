# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'time'
require 'rackstash/formatter'

RSpec.describe Rackstash::Formatter do
  let(:formatter) { described_class.new }

  it 'formats plain strings' do
    expect(formatter.call('ERROR', Time.now, 'progname', 'Hello'))
      .to eql("Hello\n")
      .and be_frozen
  end

  it 'formats stringifiable objects' do
    expect(formatter.call('ERROR', Time.now, 'progname', 123))
      .to eql("123\n")
      .and be_frozen
  end

  it 'formats Arrays' do
    expect(formatter.call('ERROR', Time.now, 'progname', [1, 'y']))
      .to eql("[1, \"y\"]\n")
      .and be_frozen
  end

  it 'formats exceptions' do
    exception = nil
    begin
      raise StandardError, 'An Error'
    rescue StandardError => e
      exception = e
    end

    checker = Regexp.new <<-REGEXP.gsub(/^\s+/, '').rstrip, Regexp::MULTILINE
      \\AAn Error \\(StandardError\\)
      #{Regexp.escape __FILE__}:#{__LINE__ - 7}:in `block .*`
    REGEXP
    expect(formatter.call('ERROR', Time.now, 'progname', exception))
      .to match(checker)
      .and be_frozen
  end

  it 'inspects unknown objects' do
    object = Object.new
    inspected = object.inspect

    expect(object).to receive(:inspect).once.and_call_original
    expect(formatter.call('ERROR', Time.now, 'progname', object))
      .to eql("#{inspected}\n")
      .and be_frozen
  end
end
