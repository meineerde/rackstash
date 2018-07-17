# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/rack/errors'

RSpec.describe Rackstash::Rack::Errors do
  let(:logger) { instance_double(Rackstash::Logger) }
  let(:errors) { described_class.new(logger) }

  describe '#initialize' do
    it 'takes a logger' do
      errors = described_class.new(logger)
      expect(errors.logger).to equal logger
    end
  end

  describe '#puts' do
    it 'logs a formatted message' do
      expect(logger).to receive(:unknown).with('an error')
      errors.puts('an error')
    end

    it 'returns the stringified message' do
      allow(logger).to receive(:unknown)

      expect(errors.puts('error')).to eql 'error'
      expect(errors.puts(123)).to eql '123'
    end
  end

  describe '#write' do
    it 'logs an unformatted message' do
      expect(logger).to receive(:<<).with('an error')
      errors.write('an error')
    end

    it 'returns the raw message' do
      allow(logger).to receive(:<<)

      expect(errors.write('error')).to eql 'error'
      expect(errors.write(123)).to eql 123
    end
  end

  describe '#flush' do
    it 'does nothing' do
      errors.flush
    end
  end

  describe '#close' do
    it 'closes the logger' do
      expect(logger).to receive(:close)
      errors.close
    end
  end
end
