# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'time'
require 'rackstash/formatter'

describe Rackstash::Formatter do
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

describe Rackstash::RawFormatter do
  let(:formatter) { described_class.new }

  it 'returns the message' do
    msg = 'my message'
    expect(formatter.call('ERROR', Time.now, 'progname', msg)).to equal msg
  end

  it 'inspects non-string messages' do
    obj = Object.new

    expect(obj).to receive(:inspect).and_return('object')
    expect(formatter.call('ERROR', Time.now, 'progname', obj)).to eql 'object'
  end
end
