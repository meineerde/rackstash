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
  let(:message_args) { {} }
  let(:msg) { 'message' }
  let(:message) { described_class.new msg, **message_args }

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

    it 'freezes the Message' do
      expect(described_class.new('message')).to be_frozen
    end
  end

  describe '#copy_with' do
    it 'creates a new message instance' do
      expect(message.copy_with).to be_instance_of described_class
      expect(message.copy_with.message).to equal message.message
      expect(message.copy_with.severity).to equal message.severity
      expect(message.copy_with.progname).to equal message.progname
      expect(message.copy_with.time).to equal message.time

      expect(message.copy_with).not_to equal message
    end

    it 'can overwrite the message' do
      expect(message.copy_with('new stuff').message).to eql 'new stuff'
    end

    it 'can overwrite the severity' do
      expect(message.copy_with(severity: 3).severity).to eql 3
    end

    it 'can overwrite the progname' do
      expect(message.copy_with(progname: 'blar').progname).to eql 'blar'
    end

    it 'can overwrite the progname' do
      time = Time.now.freeze
      expect(message.copy_with(time: time).time).to equal time
    end
  end

  describe '#gsub' do
    it 'can perform simple replaces' do
      expect(message.gsub(/s/, 'S')).to be_a described_class
      expect(message.gsub(/s/, 'S').to_s).to eql 'meSSage'
    end

    it 'can perform replaces with a block' do
      expect(message.gsub(/[l-w]/) { |match| match.upcase }.to_s).to eql 'MeSSage'
      # The magic $1, $2, ... variables don't work in our block form due to
      # Ruby's strange semantics for them
    end

    it 'returns an enumerator if there is no replacement' do
      expect(message.gsub(//)).to be_a Enumerator
    end
  end

  describe '#sub' do
    it 'can perform simple replaces' do
      expect(message.sub(/s/, 'S')).to be_a described_class
      expect(message.sub(/s/, 'S').to_s).to eql 'meSsage'
    end

    it 'can perform replaces with a block' do
      expect(message.sub(/[l-w]/) { |match| match.upcase }.to_s).to eql 'Message'
      # The magic $1, $2, ... variables don't work in our block form due to
      # Ruby's strange semantics for them
    end
  end

  describe '#lstrip' do
    let(:msg) { "\t \r\t\nmy \tmessage\r\n \t" }

    it 'returns a new Message' do
      expect(message.lstrip).to be_instance_of(described_class)
      expect(message.lstrip).not_to equal message
    end

    it 'strips leading whitespace from the message' do
      msg = "\t \r\t\nmy \tmessage\r\n \t"
      expect(message.lstrip.to_s).to eql "my \tmessage\r\n \t"
    end
  end

  describe '#rstrip' do
    let(:msg) { "\t \r\t\nmy \tmessage\r\n \t" }

    it 'returns a new Message' do
      expect(message.rstrip).to be_instance_of(described_class)
      expect(message.rstrip).not_to equal message
    end

    it 'strips trailing whitespace from the message' do
      expect(message.rstrip.to_s).to eql "\t \r\t\nmy \tmessage"
    end
  end

  describe '#strip' do
    let(:msg) { "\t \r\t\nmy \tmessage\r\n \t" }

    it 'returns a new Message' do
      expect(message.strip).to be_instance_of(described_class)
      expect(message.strip).not_to equal message
    end

    it 'strips the message' do
      msg = "\t \r\t\nmy \tmessage\r\n \t"
      expect(message.strip.to_s).to eql "my \tmessage"
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
