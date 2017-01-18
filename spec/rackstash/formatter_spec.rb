# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'time'
require 'rackstash/formatter'

describe Rackstash::Formatter do
  let(:formatter) { Rackstash::Formatter.new }

  it 'formats plain strings' do
    expect(formatter.call('ERROR', Time.now, 'progname', 'Hello')).to eql "Hello\n"
  end

  it 'formats stringifiable objects' do
    expect(formatter.call('ERROR', Time.now, 'progname', 123)).to eql "123\n"
  end

  it 'formats Hashes' do
    expect(formatter.call('ERROR', Time.now, 'progname', { k: 'v' })).to eql "{:k=>\"v\"}\n"
  end

  it 'formats exceptions' do
    exception = nil
    begin
      raise StandardError, 'An Error'
    rescue => e
      exception = e
    end

    checker = Regexp.new <<-EOF.gsub(/^\s+/, '').rstrip, Regexp::MULTILINE
      \\AAn Error \\(StandardError\\)
      #{Regexp.escape __FILE__}:#{__LINE__ - 7}:in `block .*`
    EOF
    expect(formatter.call('ERROR', Time.now, 'progname', exception)).to match checker
  end

  it 'inspects unknown objects' do
    object = Object.new
    inspected = object.inspect

    expect(object).to receive(:inspect).once.and_call_original
    expect(formatter.call('ERROR', Time.now, 'progname', object)).to eql "#{inspected}\n"
  end
end
