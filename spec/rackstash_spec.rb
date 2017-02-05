# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

describe Rackstash do
  it 'defines PROGRAME with the correct version' do
    expect(Rackstash::PROGNAME).to match %r{\Arackstash/v\d+(\..+)*\z}
    expect(Rackstash::PROGNAME).to be_frozen
  end

  it 'defines SEVERITIES constants' do
    expect(Rackstash::SEVERITIES).to eql (0..5).to_a

    expect(Rackstash::DEBUG).to eql 0
    expect(Rackstash::INFO).to eql 1
    expect(Rackstash::WARN).to eql 2
    expect(Rackstash::ERROR).to eql 3
    expect(Rackstash::FATAL).to eql 4
    expect(Rackstash::UNKNOWN).to eql 5
  end

  it 'defines EMPTY_* constants' do
    expect(Rackstash::EMPTY_STRING).to eql ''
    expect(Rackstash::EMPTY_STRING).to be_frozen

    expect(Rackstash::EMPTY_SET).to eql Set.new
    expect(Rackstash::EMPTY_SET).to be_frozen

    expect(Rackstash::ISO8601_PRECISION).to be_a Integer
  end

  it 'defines FIELD_* constants' do
    constants = Rackstash.constants.select { |c| c.to_s.start_with?('FIELD_') }

    expect(constants).not_to be_empty
    constants.each do |name|
      expect(Rackstash.const_get(name)).to be_a String
      expect(Rackstash.const_get(name)).to be_frozen
    end
  end
end
