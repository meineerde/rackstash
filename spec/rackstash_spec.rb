# frozen_string_literal: true

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
    expect(Rackstash::SEVERITIES).to eql((0..5).to_a)

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
  end

  it 'defines ISO8601_PRECISION' do
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

  it 'defines UNDEFINED' do
    expect(Rackstash::UNDEFINED).to be_instance_of Rackstash::UndefinedClass
    expect(Rackstash::UNDEFINED.to_s).to eql 'undefined'

    expect(Rackstash::UNDEFINED).to equal Rackstash::UNDEFINED

    expect(Rackstash::UNDEFINED).not_to eql nil
    expect(Rackstash::UNDEFINED).not_to eql false
    expect(Rackstash::UNDEFINED).not_to eql true
    expect(Rackstash::UNDEFINED).not_to eql 42
  end

  describe '.severity_label' do
    it 'returns the label for an integer severity' do
      expect(described_class.severity_label(0)).to eql 'DEBUG'
      expect(described_class.severity_label(4)).to eql 'FATAL'
      expect(described_class.severity_label(5)).to eql 'ANY'
    end

    it 'returns ANY for out-of-range severities' do
      expect(described_class.severity_label(-3)).to eql 'ANY'
      expect(described_class.severity_label(42)).to eql 'ANY'
    end

    it 'returns the label for a named severity' do
      expect(described_class.severity_label('DeBuG')).to eql 'DEBUG'
      expect(described_class.severity_label('warn')).to eql 'WARN'
      expect(described_class.severity_label(:error)).to eql 'ERROR'
      expect(described_class.severity_label('UnknoWn')).to eql 'ANY'
    end

    it 'returns ANY for unknown severity names' do
      expect(described_class.severity_label('foo')).to eql 'ANY'
      expect(described_class.severity_label(:test)).to eql 'ANY'
      expect(described_class.severity_label(nil)).to eql 'ANY'
    end
  end

  describe '.error_flow' do
    it 'returns a default Flow' do
      expect(described_class.error_flow).to be_instance_of Rackstash::Flow

      expect(described_class.error_flow.encoder).to be_instance_of Rackstash::Encoders::JSON
      expect(described_class.error_flow.adapter).to be_instance_of Rackstash::Adapters::IO
    end

    it 'caches the flow' do
      expect(described_class.error_flow).to equal described_class.error_flow
    end
  end

  describe '.error_flow=' do
    let(:flow) {
      flow = instance_double('Rackstash::Flow')
      allow(flow).to receive(:is_a?).with(Rackstash::Flow).and_return(true)
      flow
    }

    it 'can set a new flow' do
      described_class.error_flow = flow
      expect(described_class.error_flow).to equal flow
    end

    it 'wraps a non-flow' do
      adapter = 'spec.log'
      expect(Rackstash::Flow).to receive(:new).with(adapter).and_return(flow)

      described_class.error_flow = adapter
      expect(described_class.error_flow).to equal flow
    end
  end
end
