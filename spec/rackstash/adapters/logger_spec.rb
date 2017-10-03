# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'stringio'

require 'rackstash/adapters/logger'

describe Rackstash::Adapters::Logger do
  let(:bucket) {
    Struct.new(:lines) do
      def write(log)
        raise IOError if @closed
        lines << log
      end

      def close
        @closed = true
      end

      def closed?
        @closed
      end
    end.new([])
  }
  let(:logger) {
    ::Logger.new(bucket).tap do |logger|
      logger.formatter = ->(_severity, _time, _progname, msg) { msg }

      # mock the reopen method on this logger
      def logger.reopen
      end
    end
   }
  let(:logger_ducky) {
    Object.new.tap do |duck|
      allow(duck).to receive(:add)
    end
  }

  let(:adapter) { described_class.new(logger) }

  describe '#initialize' do
    it 'accepts a Logger object' do
      expect { described_class.new(logger) }.not_to raise_error
      expect { described_class.new(logger_ducky) }.not_to raise_error
    end

    it 'rejects non-logger objects' do
      expect { described_class.new(nil) }.to raise_error TypeError
      expect { described_class.new('hello') }.to raise_error TypeError
      expect { described_class.new(Object.new) }.to raise_error TypeError
    end
  end

  describe '.default_encoder' do
    it 'returns a JSON encoder' do
      expect(adapter.default_encoder).to be_instance_of Rackstash::Encoders::JSON
    end
  end

  describe '#close' do
    context 'with logger' do
      it 'closes the logger object' do
        expect(bucket).not_to be_closed
        expect(logger).to receive(:close).and_call_original
        adapter.close
        expect(bucket).to be_closed
      end
    end

    context 'with logger_ducky' do
      let(:logger) { logger_ducky }

      it 'ignores the call if unsupported' do
        expect { adapter.close }.not_to raise_error
      end
    end
  end

  describe '#reopen' do
    context 'with logger' do
      it 'closes the logger object' do
        expect(logger).to receive(:reopen).and_call_original
        adapter.reopen
      end
    end

    context 'with logger_ducky' do
      let(:logger) { logger_ducky }

      it 'ignores the call if unsupported' do
        expect { adapter.reopen }.not_to raise_error
      end
    end
  end

  describe '#write_single' do
    it 'writes the log line to the logger object' do
      adapter.write('a log line')
      expect(bucket.lines.last).to eql 'a log line'
    end

    it 'passes the raw object to the logger' do
      adapter.write([123, 'hello'])
      expect(bucket.lines.last).to eql [123, 'hello']
    end

    it 'removes a trailing newline if present' do
      adapter.write("a full line.\n")
      expect(bucket.lines.last).to eql 'a full line.'
    end
  end
end
