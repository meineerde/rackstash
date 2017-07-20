# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/logger'

describe Rackstash::Logger do
  let(:target) { StringIO.new }
  let(:logger) { described_class.new(target) }

  describe '#initialize' do
    it 'requires flows' do
      expect(Rackstash::Sink).to receive(:new).with('output.log')
      described_class.new('output.log')
    end

    it 'allows to set #level' do
      logger = described_class.new('output.log', level: 'ERROR')
      expect(logger.level).to eql 3

      logger = described_class.new('output.log', level: 2)
      expect(logger.level).to eql 2
    end

    it 'allows to set #progname' do
      logger = described_class.new('output.log', progname: 'myapp')
      expect(logger.progname).to eql 'myapp'
    end

    it 'allows to set #formatter' do
      logger = described_class.new('output.log', formatter: ->{})
      expect(logger.formatter).to be_a Proc
    end
  end

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

  describe '#fields' do
    it 'gets the current buffer\'s fields' do
      buffer = instance_double('Rackstash::Buffer')
      expect(logger).to receive(:buffer).and_return(buffer)
      expect(buffer).to receive(:fields)

      logger.fields
    end

    it 'returns a Rackstash::Fields::Hash' do
      expect(logger.fields).to be_a Rackstash::Fields::Hash
    end
  end

  describe '#tags' do
    it 'gets the current buffer\'s tags' do
      buffer = instance_double('Rackstash::Buffer')
      expect(logger).to receive(:buffer).and_return(buffer)
      expect(buffer).to receive(:tags)

      logger.tags
    end

    it 'returns a Rackstash::Fields::Tags' do
      expect(logger.tags).to be_a Rackstash::Fields::Tags
    end
  end

  describe '#add' do
    let(:messages) { [] }

    let(:buffer) {
      double('Rackstash::Buffer').tap do |buffer|
        allow(buffer).to receive(:add_message) { |message| messages << message }
      end
    }

    let(:buffer_stack) {
      double('Rackstash::BufferStack').tap do |buffer_stack|
        expect(buffer_stack).to receive(:current)
          .at_least(:once)
          .and_return(buffer)
      end
    }

    before do
      class_double('Rackstash::Message').as_stubbed_const.tap do |klass|
        allow(klass).to receive(:new) { |msg, **kwargs| { message: msg, **kwargs } }
      end
      allow(logger).to receive(:buffer_stack).and_return(buffer_stack)
    end

    it 'sets the current time as UTC to the message' do
      logger.add(nil, 'msg')
      expect(messages.last[:time]).to be_a(Time).and be_frozen.and be_utc
    end

    it 'sets the provided a severity' do
      logger.log(Rackstash::DEBUG, 'Debug message')
      expect(messages.last).to include message: "Debug message\n", severity: 0

      logger.log(Rackstash::INFO, 'Info message')
      expect(messages.last).to include message: "Info message\n", severity: 1

      logger.log(Rackstash::WARN, 'Warn message')
      expect(messages.last).to include message: "Warn message\n", severity: 2

      logger.log(Rackstash::ERROR, 'Error message')
      expect(messages.last).to include message: "Error message\n", severity: 3

      logger.log(Rackstash::FATAL, 'Fatal message')
      expect(messages.last).to include message: "Fatal message\n", severity: 4

      logger.log(Rackstash::UNKNOWN, 'Unknown message')
      expect(messages.last).to include message: "Unknown message\n", severity: 5

      # Positive severities are passed along
      logger.log(42, 'The answer')
      expect(messages.last).to include message: "The answer\n", severity: 42

      # nil is changed to UNKNOWN
      logger.log(nil, 'Missing')
      expect(messages.last).to include message: "Missing\n", severity: 5

      # Non-number arguments result in an error
      expect { logger.log(:debug, 'Missing') }.to raise_error(TypeError)
      expect { logger.log('debug', 'Missing') }.to raise_error(ArgumentError)
    end

    it 'defaults to severity to UNKNOWN' do
      logger.add(nil, 'test')
      expect(messages.last).to include severity: 5
    end

    it 'formats the message' do
      formatter = double('formatter')
      logger.formatter = formatter
      expect(formatter).to receive(:call)
        .with('DEBUG', instance_of(Time), Rackstash::PROGNAME, 'Hello World')

      logger.add(0, 'Hello World')
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
        message: "Hello\n", severity: 0, progname: Rackstash::PROGNAME
      )

      logger.add(4, 'Hello', 'prog')
      expect(messages.last).to include(
        message: "Hello\n", severity: 4, progname: 'prog'
      )

      logger.add(5, 'Hello', 'prog') { 'block' }
      expect(messages.last).to include(
        message: "Hello\n", severity: 5, progname: 'prog'
      )

      logger.add(nil, 'Hello', nil)
      expect(messages.last).to include(
        message: "Hello\n", severity: 5, progname: Rackstash::PROGNAME
      )

      # If there is no message, we use the block
      logger.add(1, nil, 'prog') { 'Hello' }
      expect(messages.last).to include(
        message: "Hello\n", severity: 1, progname: 'prog'
      )
      logger.add(1, nil, nil) { 'Hello' }
      expect(messages.last).to include(
        message: "Hello\n", severity: 1, progname: Rackstash::PROGNAME
      )

      # If there is no block either, we use the progname and pass the default
      # progname to the message
      logger.add(2, nil, 'prog')
      expect(messages.last).to include(
        message: "prog\n", severity: 2, progname: Rackstash::PROGNAME
      )
      # ... which defaults to `Rackstash::BufferedLogger::PROGNAME`
      logger.add(3, nil, nil)
      expect(messages.last).to include(
        message: "#{Rackstash::PROGNAME}\n", severity: 3, progname: Rackstash::PROGNAME
      )

      # If we resolve the message to a blank string, we still add it
      logger.add(1, '', nil) { 'Hello' }
      expect(messages.last).to include(
        message: "\n", severity: 1, progname: Rackstash::PROGNAME
      )
      # Same with nil which is later inspect'ed by the formatter
      logger.add(0, nil, 'prog') { nil }
      expect(messages.last).to include(
        message: "nil\n", severity: 0, progname: 'prog'
      )
    end

    it 'merges fields if message is a Hash' do
      fields = instance_double('Rackstash::Fields::Hash')
      expect(buffer).to receive(:fields).and_return(fields)
      expect(fields).to receive(:deep_merge!).with(foo: 'bar')

      expect(buffer).not_to receive(:add_message)

      expect(logger.add(0, { foo: 'bar' })).to eql(foo: 'bar')
    end

    it 'can use debug shortcut' do
      expect(logger).to receive(:add).with(0, 'Debug').and_call_original
      logger.debug('Debug')
      expect(messages.last).to include message: "Debug\n", severity: 0
    end

    it 'can use debug shortcut with a block' do
      expect(logger).to receive(:add).with(0, nil).and_call_original
      logger.debug { 'Debug' }
      expect(messages.last).to include message: "Debug\n", severity: 0
    end

    it 'can use info shortcut' do
      expect(logger).to receive(:add).with(1, 'Info').and_call_original
      logger.info('Info')
      expect(messages.last).to include message: "Info\n", severity: 1
    end

    it 'can use info shortcut with a block' do
      expect(logger).to receive(:add).with(1, nil).and_call_original
      logger.info { 'Info' }
      expect(messages.last).to include message: "Info\n", severity: 1
    end

    it 'can use warn shortcut' do
      expect(logger).to receive(:add).with(2, 'Warn').and_call_original
      logger.warn('Warn')
      expect(messages.last).to include message: "Warn\n", severity: 2
    end

    it 'can use warn shortcut with a block' do
      expect(logger).to receive(:add).with(2, nil).and_call_original
      logger.warn { 'Warn' }
      expect(messages.last).to include message: "Warn\n", severity: 2
    end

    it 'can use error shortcut' do
      expect(logger).to receive(:add).with(3, 'Error').and_call_original
      logger.error('Error')
      expect(messages.last).to include message: "Error\n", severity: 3
    end

    it 'can use error shortcut with a block' do
      expect(logger).to receive(:add).with(3, nil).and_call_original
      logger.error { 'Error' }
      expect(messages.last).to include message: "Error\n", severity: 3
    end

    it 'can use fatal shortcut' do
      expect(logger).to receive(:add).with(4, 'Fatal').and_call_original
      logger.fatal('Fatal')
      expect(messages.last).to include message: "Fatal\n", severity: 4
    end

    it 'can use fatal shortcut with a block' do
      expect(logger).to receive(:add).with(4, nil).and_call_original
      logger.fatal { 'Fatal' }
      expect(messages.last).to include message: "Fatal\n", severity: 4
    end

    it 'can use unknown shortcut' do
      expect(logger).to receive(:add).with(5, 'Unknown').and_call_original
      logger.unknown('Unknown')
      expect(messages.last).to include message: "Unknown\n", severity: 5
    end

    it 'can use unknown shortcut with a block' do
      expect(logger).to receive(:add).with(5, nil).and_call_original
      logger.unknown { 'Unknown' }
      expect(messages.last).to include message: "Unknown\n", severity: 5
    end

    it 'can add a raw message with <<' do
      logger << :raw_value
      expect(messages.last).to include(
        message: :raw_value,
        severity: 5,
        time: instance_of(Time)
      )
    end
  end

  describe '#add_exception' do
    let(:fields) { Rackstash::Fields::Hash.new }

    before(:each) do
      buffer = instance_double('Rackstash::Buffer')
      allow(buffer).to receive(:fields).and_return(fields)
      allow(logger).to receive(:buffer).and_return(buffer)
    end

    it 'adds the exception fields' do
      begin
        raise 'My Error'
      rescue => e
        logger.add_exception(e)
      end

      expect(fields['error']).to eql 'RuntimeError'
      expect(fields['error_message']).to eql 'My Error'
      expect(fields['error_trace']).to match %r{\A#{__FILE__}:#{__LINE__ - 7}:in}
    end

    it 'does not require a backtrace' do
      logger.add_exception(StandardError.new('Error'))

      expect(fields['error']).to eql 'StandardError'
      expect(fields['error_message']).to eql 'Error'
      expect(fields['error_trace']).to eql ''
    end

    context 'with force: true' do
      it 'overwrites exceptions' do
        begin
          raise 'Error'
        rescue => first
          logger.add_exception(first, force: true)
        end

        begin
          raise TypeError, 'Another Error'
        rescue => second
          logger.add_exception(second, force: true)
        end

        expect(fields['error']).to eql 'TypeError'
        expect(fields['error_message']).to eql 'Another Error'
        expect(fields['error_trace']).to match %r{\A#{__FILE__}:#{__LINE__ - 7}:in}
      end
    end

    context 'with force: false' do
      it 'does not overwrite exceptions' do
        fields['error'] = 'Something is wrong'

        begin
          raise TypeError, 'Error'
        rescue => second
          logger.add_exception(second, force: false)
        end

        expect(fields['error']).to eql 'Something is wrong'
        expect(fields['error_message']).to be_nil
        expect(fields['error_trace']).to be_nil
      end
    end
  end

  describe '#with_buffer' do
    it 'requires a block' do
      expect { logger.with_buffer }.to raise_error ArgumentError
    end

    it 'adds a new buffer' do
      expect(logger.send(:buffer_stack)).to receive(:push).and_call_original
      expect(logger.send(:buffer_stack)).to receive(:flush_and_pop).and_call_original

      logger.fields['key'] = 'outer'
      logger.with_buffer do
        expect(logger.fields['key']).to be nil
        logger.fields['key'] = 'inner'
      end
      expect(logger.fields['key']).to eql 'outer'
    end

    it 'buffers multiple messages' do
      expect(logger.sink).to receive(:write).once

      logger.with_buffer do
        logger.add 1, 'Hello World'
        logger.add 0, 'I feel great'
      end
    end
  end

  context 'with multiple threads' do
    it '#buffer_stack maintains thread-local stacks' do
      first_stack = logger.send(:buffer_stack)
      expect(first_stack).to be_a Rackstash::BufferStack

      Thread.new do
        second_stack = logger.send(:buffer_stack)
        expect(second_stack).to be_a Rackstash::BufferStack

        expect(second_stack).to_not eql first_stack
      end.join
    end
  end
end
