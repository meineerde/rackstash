# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/logger'

describe Rackstash::Logger do
  let(:targets) { double('targets') }
  let(:logger) { Rackstash::Logger.new(targets) }

  describe '#formatter' do
    it 'defaults to a Rackstash::Formatter' do
      expect(logger.formatter).to be_a Rackstash::Formatter
    end

    it 'allows to set a custom formatter' do
      formatter = ->(_severity, _time, _progname, msg) { msg.reverse }
      logger.formatter = formatter
      expect(logger.formatter).to equal formatter
    end
  end

  describe '#level' do
    it 'defaults to DEBUG' do
      expect(logger.level).to eql 0
    end

    it 'can be set as an integer' do
      logger.level = 3
      expect(logger.level).to eql 3

      logger.level = 42
      expect(logger.level).to eql 42

      logger.level = -25
      expect(logger.level).to eql(-25)
    end

    it 'can be set as a symbol' do
      %i[debug info warn error fatal unknown].each_with_index do |level, i|
        logger.level = level
        expect(logger.level).to eql i
      end

      %i[DeBuG InFo WaRn ErRoR FaTaL UnKnOwN].each_with_index do |level, i|
        logger.level = level
        expect(logger.level).to eql i
      end
    end

    it 'can be set as a string' do
      %w[debug info warn error fatal unknown].each_with_index do |level, i|
        logger.level = level
        expect(logger.level).to eql i
      end

      %w[DeBuG InFo WaRn ErRoR FaTaL UnKnOwN].each_with_index do |level, i|
        logger.level = level
        expect(logger.level).to eql i
      end
    end

    it 'rejects invalid values' do
      expect { logger.level = 'invalid' }.to raise_error(ArgumentError)
      expect { logger.level = Object.new }.to raise_error(ArgumentError)
      expect { logger.level = nil }.to raise_error(ArgumentError)
      expect { logger.level = false }.to raise_error(ArgumentError)
      expect { logger.level = true }.to raise_error(ArgumentError)
    end

    it 'can set all the levels' do
      levels = %i[debug info warn error fatal unknown]

      levels.each_with_index do |level, number|
        logger.level = level
        expect(logger.level).to eql number

        # only severities larger then the selected one are logged
        levels.each_with_index do |check_level, check_number|
          expect(logger.public_send(:"#{check_level}?")).to eql number <= check_number
        end
      end
    end
  end

  describe '#progname' do
    it 'defaults to PROGNAME' do
      expect(logger.progname).to match %r{\Arackstash/v\d+(\..+)*\z}
    end

    it 'can be set to a custom value' do
      logger.progname = 'my app'
      expect(logger.progname).to eql 'my app'
    end
  end

  describe '#sink' do
    it 'returns the created sink' do
      expect(logger.sink).to be_a Rackstash::Sink
    end
  end

  describe '#add' do
    let(:messages) { [] }

    let(:buffer) {
      double('Rackstash::Buffer').tap do |buffer|
        expect(buffer).to receive(:add_message) { |message| messages << message }
          .at_least(:once)
      end
    }

    let(:buffer_stack) {
      double('Rackstash::BufferStack').tap do |buffer_stack|
        expect(buffer_stack).to receive(:with_buffer)
          .at_least(:once)
          .and_yield(buffer)
      end
    }

    before do
      class_double('Rackstash::Message').as_stubbed_const.tap do |klass|
        expect(klass).to receive(:new) { |msg, **kwargs| { message: msg, **kwargs } }
          .at_least(:once)
      end
      expect(logger).to receive(:buffer_stack)
        .at_least(:once)
        .and_return(buffer_stack)
    end

    it 'sets the current time as UTC to the message' do
      logger.add(nil, 'msg')
      expect(messages.last[:time]).to be_a(Time).and be_frozen.and be_utc
    end

    it 'sets the provided a severity' do
      logger.log(Rackstash::DEBUG, 'Debug message')
      expect(messages.last).to include message: 'Debug message', severity: 0

      logger.log(Rackstash::INFO, 'Info message')
      expect(messages.last).to include message: 'Info message', severity: 1

      logger.log(Rackstash::WARN, 'Warn message')
      expect(messages.last).to include message: 'Warn message', severity: 2

      logger.log(Rackstash::ERROR, 'Error message')
      expect(messages.last).to include message: 'Error message', severity: 3

      logger.log(Rackstash::FATAL, 'Fatal message')
      expect(messages.last).to include message: 'Fatal message', severity: 4

      logger.log(Rackstash::UNKNOWN, 'Unknown message')
      expect(messages.last).to include message: 'Unknown message', severity: 5

      # Positive severities are passed along
      logger.log(42, 'The answer')
      expect(messages.last).to include message: 'The answer', severity: 42

      # nil is changed to UNKNOWN
      logger.log(nil, 'Missing')
      expect(messages.last).to include message: 'Missing', severity: 5

      # Non-number arguments result in an error
      expect { logger.log(:debug, 'Missing') }.to raise_error(TypeError)
      expect { logger.log('debug', 'Missing') }.to raise_error(ArgumentError)
    end

    it 'defaults to severity to UNKNOWN' do
      logger.add(nil, 'test')
      expect(messages.last).to include severity: 5
    end

    it 'calls the block if message is nil' do
      temp = 0
      expect do
        logger.log(nil, nil, 'TestApp') do
          temp = 1 + 1
        end
      end.to_not raise_error
      expect(temp).to eql 2
    end

    it 'ignores the block if the message is not nil' do
      temp = 0
      expect do
        logger.log(nil, 'not nil', 'TestApp') do
          temp = 1 + 1
        end
      end.to_not raise_error
      expect(temp).to eql 0
    end

    it 'follows Ruby\'s logger logic to find the message' do
      # If there is a message, it will be logged
      logger.add(0, 'Hello', nil)
      expect(messages.last).to include(
        message: 'Hello', severity: 0, progname: Rackstash::PROGNAME
      )

      logger.add(4, 'Hello', 'prog')
      expect(messages.last).to include(
        message: 'Hello', severity: 4, progname: 'prog'
      )

      logger.add(5, 'Hello', 'prog') { 'block' }
      expect(messages.last).to include(
        message: 'Hello', severity: 5, progname: 'prog'
      )

      logger.add(nil, 'Hello', nil)
      expect(messages.last).to include(
        message: 'Hello', severity: 5, progname: Rackstash::PROGNAME
      )

      # If there is no message, we use the block
      logger.add(1, nil, 'prog') { 'Hello' }
      expect(messages.last).to include(
        message: 'Hello', severity: 1, progname: 'prog'
      )
      logger.add(1, nil, nil) { 'Hello' }
      expect(messages.last).to include(
        message: 'Hello', severity: 1, progname: Rackstash::PROGNAME
      )

      # If there is no block either, we use the progname and pass the default
      # progname to the message
      logger.add(2, nil, 'prog')
      expect(messages.last).to include(
        message: 'prog', severity: 2, progname: Rackstash::PROGNAME
      )
      # ... which defaults to `Rackstash::BufferedLogger::PROGNAME`
      logger.add(3, nil, nil)
      expect(messages.last).to include(
        message: Rackstash::PROGNAME, severity: 3, progname: Rackstash::PROGNAME
      )

      # If we resolve the message to a blank string, we still add it
      logger.add(1, '', nil) { 'Hello' }
      expect(messages.last).to include(
        message: '', severity: 1, progname: Rackstash::PROGNAME
      )
      # Same with nil which is later inspect'ed by the formatter
      logger.add(0, nil, 'prog') { nil }
      expect(messages.last).to include(
        message: nil, severity: 0, progname: 'prog'
      )
    end

    it 'can use debug shortcut' do
      expect(logger).to receive(:add).with(0, 'Debug').and_call_original
      logger.debug('Debug')
      expect(messages.last).to include message: 'Debug', severity: 0
    end

    it 'can use debug shortcut with a block' do
      expect(logger).to receive(:add).with(0, nil).and_call_original
      logger.debug { 'Debug' }
      expect(messages.last).to include message: 'Debug', severity: 0
    end

    it 'can use info shortcut' do
      expect(logger).to receive(:add).with(1, 'Info').and_call_original
      logger.info('Info')
      expect(messages.last).to include message: 'Info', severity: 1
    end

    it 'can use info shortcut with a block' do
      expect(logger).to receive(:add).with(1, nil).and_call_original
      logger.info { 'Info' }
      expect(messages.last).to include message: 'Info', severity: 1
    end

    it 'can use warn shortcut' do
      expect(logger).to receive(:add).with(2, 'Warn').and_call_original
      logger.warn('Warn')
      expect(messages.last).to include message: 'Warn', severity: 2
    end

    it 'can use warn shortcut with a block' do
      expect(logger).to receive(:add).with(2, nil).and_call_original
      logger.warn { 'Warn' }
      expect(messages.last).to include message: 'Warn', severity: 2
    end

    it 'can use error shortcut' do
      expect(logger).to receive(:add).with(3, 'Error').and_call_original
      logger.error('Error')
      expect(messages.last).to include message: 'Error', severity: 3
    end

    it 'can use error shortcut with a block' do
      expect(logger).to receive(:add).with(3, nil).and_call_original
      logger.error { 'Error' }
      expect(messages.last).to include message: 'Error', severity: 3
    end

    it 'can use fatal shortcut' do
      expect(logger).to receive(:add).with(4, 'Fatal').and_call_original
      logger.fatal('Fatal')
      expect(messages.last).to include message: 'Fatal', severity: 4
    end

    it 'can use fatal shortcut with a block' do
      expect(logger).to receive(:add).with(4, nil).and_call_original
      logger.fatal { 'Fatal' }
      expect(messages.last).to include message: 'Fatal', severity: 4
    end

    it 'can use unknown shortcut' do
      expect(logger).to receive(:add).with(5, 'Unknown').and_call_original
      logger.unknown('Unknown')
      expect(messages.last).to include message: 'Unknown', severity: 5
    end

    it 'can use unknown shortcut with a block' do
      expect(logger).to receive(:add).with(5, nil).and_call_original
      logger.unknown { 'Unknown' }
      expect(messages.last).to include message: 'Unknown', severity: 5
    end
  end
end
