# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'stringio'
require 'tempfile'

require 'rackstash/adapters/io'

describe Rackstash::Adapters::IO do
  let(:io) { StringIO.new }
  let(:adapter) { Rackstash::Adapters::IO.new(io) }

  describe '#initialize' do
    it 'accepts an IO object' do
      expect { Rackstash::Adapters::IO.new($stdout) }.not_to raise_error
      expect { Rackstash::Adapters::IO.new(StringIO.new) }.not_to raise_error
      expect { Rackstash::Adapters::IO.new(Tempfile.new('foo')) }.not_to raise_error
    end

    it 'rejects non-IO objects' do
      expect { Rackstash::Adapters::IO.new(nil) }.to raise_error TypeError
      expect { Rackstash::Adapters::IO.new('hello') }.to raise_error TypeError
      expect { Rackstash::Adapters::IO.new(Object.new) }.to raise_error TypeError
    end
  end

  describe '.default_encoder' do
    it 'returns a JSON encoder' do
      expect(adapter.default_encoder).to be_instance_of Rackstash::Encoders::JSON
    end
  end

  describe '#close' do
    it 'closes the IO object' do
      expect(io).to receive(:close).and_call_original
      adapter.close
      expect { adapter.write('hello') }.to raise_error IOError
    end
  end

  describe '#reopen' do
    it 'does nothing' do
      expect(io).not_to receive(:close)
      adapter.reopen
    end
  end

  describe '#write_single' do
    it 'writes the log line to the IO object' do
      adapter.write('a log line')
      expect(io.tap(&:rewind).read).to eql "a log line\n"
    end

    it 'always writes a string' do
      adapter.write([123, 'hello'])
      expect(io.tap(&:rewind).read).to eql "[123, \"hello\"]\n"
    end

    it 'appends a trailing newline if necessary' do
      adapter.write("a full line.\n")
      expect(io.tap(&:rewind).read).to eql "a full line.\n"
    end

    context 'with flush_immediately' do
      before do
        adapter.flush_immediately = true
      end

      it 'flushes after each write' do
        expect(io).to receive(:flush).twice
        adapter.write('foo')
        adapter.write('bar')
      end
    end
  end
end
