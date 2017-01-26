# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'digest'
require 'rackstash/message'

describe Rackstash::Message do
  describe '#message' do
    it 'dups the message string' do
      str = 'a message'.encode(Encoding::ASCII_8BIT)
      message = Rackstash::Message.new(str)

      expect(message.message).to eql str
      expect(message.message).not_to equal str
      expect(message.message.encoding).to eql Encoding::ASCII_8BIT
      expect(message.message).to be_frozen
    end

    it 'accepts non-string objects' do
      exception = StandardError.new('An error')
      message = Rackstash::Message.new(exception)

      expect(message.message).to eq exception
    end

    it 'attempts to dup non-frozen objects' do
      rational = Rational(2, 3)
      expect(rational).to_not be_frozen

      message = Rackstash::Message.new(rational)

      expect(message.message).to_not be_frozen
      expect(message.message).to equal rational
    end
  end

  describe '#severity' do
    it 'defaults to UNKNOWN' do
      expect(Rackstash::Message.new('').severity).to eql 5
    end

    it 'accepts any non-negative integer' do
      expect(Rackstash::Message.new('', severity: 0).severity).to eql 0
      expect(Rackstash::Message.new('', severity: 1).severity).to eql 1
      expect(Rackstash::Message.new('', severity: 23).severity).to eql 23
      expect(Rackstash::Message.new('', severity: '3').severity).to eql 3
    end

    it 'uses 0 for negative severities' do
      expect(Rackstash::Message.new('', severity: -1).severity).to eql 0
      expect(Rackstash::Message.new('', severity: -42).severity).to eql 0
    end

    it 'does not accept non-integers' do
      expect { Rackstash::Message.new('', severity: nil) }.to raise_error TypeError
      expect { Rackstash::Message.new('', severity: [42]) }.to raise_error TypeError
      expect { Rackstash::Message.new('', severity: 'foo') }.to raise_error ArgumentError
    end
  end

  describe '#severity_label' do
    it 'formats the given severity as a string' do
      %w[DEBUG INFO WARN ERROR FATAL ANY].each_with_index do |label, severity|
        expect(Rackstash::Message.new('', severity: severity).severity_label).to eql label
      end
    end

    it 'returns ANY for unknown severities' do
      expect(Rackstash::Message.new('', severity: 42).severity_label).to eql 'ANY'
    end
  end

  describe 'progname' do
    it 'dups the progname' do
      progname = 'a message'
      message = Rackstash::Message.new('', progname: progname)

      expect(message.progname).to eql progname
      expect(message.progname).not_to equal progname
      expect(message.progname).to be_frozen
    end

    it 'defaults to PROGNAME' do
      expect(Rackstash::Message.new('').progname).to match %r{\Arackstash/v\d+(\..+)*\z}
    end
  end

  describe 'time' do
    it 'dups the time' do
      time = Time.now
      message = Rackstash::Message.new('', time: time)

      expect(message.time).to eql time
      expect(message.time).not_to equal time
      expect(message.time).to be_frozen
      # User-supplied time is not enforced to be in UTC
      expect(message.time).to_not be_utc
    end

    it 'defaults to Time.now.utc' do
      expect(Rackstash::Message.new('').time).to be_within(1).of(Time.now)
      expect(Rackstash::Message.new('').time).to be_frozen
      expect(Rackstash::Message.new('').time).to be_utc
    end
  end

  describe 'formatter' do
    it 'defaults to RAW_FORMATTER' do
      expect(Rackstash::Message.new('').formatter).to equal Rackstash::Message::RAW_FORMATTER

      message = Rackstash::Message.new('Beep boop')
      expect(message.to_s).to eql 'Beep boop'
    end
  end

  describe '#to_s' do
    it 'formats the message' do
      severity = 0
      time = Time.now
      progname = 'ProgramName'
      message = 'Hello World'

      formatter = double('formatter')
      expect(formatter).to receive(:call)
        .with('DEBUG', time, progname, message)
        .and_return('Formatted Message')

      message = Rackstash::Message.new(
        message,
        severity: severity,
        time: time,
        progname: progname,
        formatter: formatter
      )

      expect(message.to_s).to eql 'Formatted Message'
    end

    it 'cleans the message' do
      messages = [
        ["First\r\nSecond",         "First\nSecond"],
        ["First\r\nSecond\n\r",     "First\nSecond\n\n"],
        ["Foo\r\n\rBar",            "Foo\n\nBar"],
        ["\r \tWord\n\nPhrase\n",   "\n \tWord\n\nPhrase\n"],
        ["\e[31mRED TEXT\e[0m",     'RED TEXT']
      ]

      messages.each do |msg, clean|
        message = Rackstash::Message.new(msg)
        expect(message.to_s).to eql clean
      end
    end

    it 'encodes the message as UTF-8' do
      utf8_str = 'Dönerstraße'
      latin_str = utf8_str.encode(Encoding::ISO8859_9)
      expect(latin_str.encoding).to eql Encoding::ISO8859_9

      message = Rackstash::Message.new(latin_str)
      expect(message.to_s).to eql utf8_str
      expect(message.to_s.encoding).to eql Encoding::UTF_8
    end

    it 'does not raise an error on incompatible encodings' do
      binary = Digest::SHA256.digest('string')
      message = Rackstash::Message.new(binary)

      expect(message.to_s).to include '�'
      expect(message.to_s.encoding).to eql Encoding::UTF_8
    end

    it 'accepts non-string objects' do
      exception = StandardError.new('An error')
      message = Rackstash::Message.new(exception)

      expect(message.to_s).to eql '#<StandardError: An error>'
    end

  end

  describe '#frozen?' do
    it 'is always true' do
      expect(Rackstash::Message.new('Beep boop')).to be_frozen
    end
  end
end
