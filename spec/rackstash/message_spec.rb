# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'digest'
require 'json'
require 'rackstash/message'

describe Rackstash::Message do
  describe '#initialize' do
    it 'encodes the message as UTF-8' do
      utf8_str = 'Dönerstraße'
      latin_str = utf8_str.encode(Encoding::ISO8859_9)
      expect(latin_str.encoding).to eql Encoding::ISO8859_9

      message = described_class.new(latin_str)
      expect(message.message).to eql utf8_str
      expect(message.message.encoding).to eql Encoding::UTF_8
    end

    it 'does not raise an error on incompatible encodings' do
      binary = Digest::SHA256.digest('string')
      message = described_class.new(binary)

      expect(message.message).to include '�'
      expect(message.message.encoding).to eql Encoding::UTF_8
    end

    it 'accepts non-string objects' do
      message = described_class.new(StandardError.new('An error'))
      expect(message.message).to eql '#<StandardError: An error>'
      expect(message.message).to be_frozen

      message = described_class.new(:symbol)
      expect(message.message).to eql ':symbol'
      expect(message.message).to be_frozen
    end

    it 'dups and freezes all messages' do
      str = String.new('hello')
      expect(str.encoding).to eql Encoding::UTF_8

      message = described_class.new(str)
      expect(message.message).to be_frozen
      expect(message.message).not_to equal str
      expect(message.message).to eql str
    end
  end

  describe '#message' do
    it 'is aliased to to_str' do
      message = described_class.new('hello world')
      expect(message.to_s).to eql 'hello world'
    end

    it 'is aliased to to_str' do
      message = described_class.new('hello world')
      expect(message.to_str).to eql 'hello world'
    end

    it 'is aliased to as_json' do
      message = described_class.new('hello world')
      expect(message.as_json).to eql 'hello world'
    end
  end

  describe '#severity' do
    it 'defaults to UNKNOWN' do
      expect(described_class.new('').severity).to eql 5
    end

    it 'accepts any non-negative integer' do
      expect(described_class.new('', severity: 0).severity).to eql 0
      expect(described_class.new('', severity: 1).severity).to eql 1
      expect(described_class.new('', severity: 23).severity).to eql 23
      expect(described_class.new('', severity: '3').severity).to eql 3
    end

    it 'uses 0 for negative severities' do
      expect(described_class.new('', severity: -1).severity).to eql 0
      expect(described_class.new('', severity: -42).severity).to eql 0
    end

    it 'does not accept non-integers' do
      expect { described_class.new('', severity: nil) }.to raise_error TypeError
      expect { described_class.new('', severity: [42]) }.to raise_error TypeError
      expect { described_class.new('', severity: 'foo') }.to raise_error ArgumentError
    end
  end

  describe '#progname' do
    it 'dup-freezes a mutable progname' do
      progname = String.new('a message')
      message = described_class.new('', progname: progname)

      expect(message.progname).to eql progname
      expect(message.progname).not_to equal progname
      expect(message.progname).to be_frozen
    end

    it 'defaults to PROGNAME' do
      expect(described_class.new('').progname).to match %r{\Arackstash/v\d+(\..+)*\z}
    end
  end

  describe '#length' do
    it 'returns the size if the message' do
      message = described_class.new('hello world')
      expect(message.length).to eql 11
    end

    it 'can use the #size alias' do
      message = described_class.new('hello world')
      expect(message.size).to eql 11
    end
  end

  describe '#severity_label' do
    it 'returns the severity label' do
      expect(Rackstash).to receive(:severity_label).exactly(3).times.and_call_original
      expect(described_class.new('', severity: 0).severity_label).to eql 'DEBUG'
      expect(described_class.new('', severity: 2).severity_label).to eql 'WARN'
      expect(described_class.new('', severity: 5).severity_label).to eql 'ANY'
    end
  end

  describe '#time' do
    it 'dups the time' do
      time = Time.now
      message = described_class.new('', time: time)

      expect(message.time).to eql time
      expect(message.time).not_to equal time
      expect(message.time).to be_frozen
      # User-supplied time is not enforced to be in UTC
      expect(message.time).to_not be_utc
    end

    it 'defaults to Time.now.utc' do
      expect(described_class.new('').time).to be_within(1).of(Time.now)
      expect(described_class.new('').time).to be_frozen
      expect(described_class.new('').time).to be_utc
    end
  end

  describe '#to_json' do
    it 'formats the message as JSON' do
      message = described_class.new('hello world')
      expect(message.to_json).to eql '"hello world"'
    end
  end
end
