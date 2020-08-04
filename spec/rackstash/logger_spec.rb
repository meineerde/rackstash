# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/logger'

RSpec.describe Rackstash::Logger do
  let(:target) { StringIO.new }
  let(:logger) { described_class.new(target) }

  describe '#initialize' do
    it 'accepts flows' do
      expect(Rackstash::Flows).to receive(:new).with('output.log')
      described_class.new('output.log')
    end

    it 'does not require any flows' do
      expect(described_class.new).to be_instance_of described_class
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
      logger = described_class.new('output.log', formatter: -> {})
      expect(logger.formatter).to be_a Proc
    end

    it 'yields the last flow to a parameterized block' do
      block_called = 0
      block_self = nil
      block_args = nil

      described_class.new(StringIO.new, StringIO.new) do |*args|
        block_called += 1
        block_self = self
        block_args = args
      end

      expect(block_called).to eql 1
      expect(block_self).to equal self
      expect(block_args).to match [instance_of(Rackstash::Flow)]
    end

    it 'instance_evals the parameter-less block in the last flow' do
      block_called = 0
      block_self = nil

      described_class.new(StringIO.new, StringIO.new) do
        block_called += 1
        block_self = self
      end

      expect(block_called).to eql 1
      expect(block_self).to be_instance_of(Rackstash::Flow)
    end

    it 'does not yield without given flows' do
      expect { |b| described_class.new(&b) }.not_to yield_control
    end
  end

  describe 'subscript accessors' do
    it 'gets a fields from the current Buffer' do
      logger['key'] = 'value'
      expect(logger['key']).to eql 'value'
    end

    it 'normalizes keys when setting values' do
      logger[:foo] = 'foo value'
      expect(logger['foo']).to eql 'foo value'

      logger[42] = '42 value'
      expect(logger['42']).to eql '42 value'
    end

    it 'returns nil if a value was not set' do
      expect(logger['missing']).to be_nil
    end

    it 'can\'t set forbidden values' do
      expect { logger['message'] = 'nope' }.to raise_error ArgumentError
      expect { logger['tags'] = 'nope' }.to raise_error ArgumentError
      expect { logger['@timestamp'] = 'nope' }.to raise_error ArgumentError
      expect { logger['@version'] = 'nope' }.to raise_error ArgumentError
    end
  end

  describe '#close' do
    it 'forwards to the flows' do
      expect(logger.flows).to receive(:close)
      logger.close
    end
  end

  describe '#flows' do
    it 'is a Rackstash::Flows' do
      expect(logger.flows).to be_instance_of Rackstash::Flows
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

    it 'resolves value with Rackstash.severity' do
      logger # initialize the logger

      expect(Rackstash).to receive(:severity).with(:ErRor).and_call_original
      logger.level = :ErRor
      expect(logger.level).to eql 3
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

  describe '#reopen' do
    it 'forwards to the flows' do
      expect(logger.flows).to receive(:reopen)
      logger.reopen
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

  describe '#tag' do
    it 'forwards to the buffer' do
      buffer = instance_double('Rackstash::Buffer')
      expect(logger).to receive(:buffer).and_return(buffer)
      expect(buffer).to receive(:tag)

      logger.tag('foo')
    end

    it 'implements the same method signature as the Buffer' do
      expect(Rackstash::Buffer.instance_method(:tag).parameters)
        .to eql logger.method(:tag).parameters
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

  describe '#timestamp' do
    it 'forwards to the Buffer' do
      buffer = instance_double('Rackstash::Buffer')
      expect(logger).to receive(:buffer).and_return(buffer)
      expect(buffer).to receive(:timestamp)

      logger.timestamp
    end

    it 'implements the same method signature as the Buffer' do
      expect(Rackstash::Buffer.instance_method(:timestamp).parameters)
        .to eql logger.method(:timestamp).parameters
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
        message: 'nil', severity: 0, progname: 'prog'
      )
    end

    it 'merges fields if message is a Hash' do
      expect(buffer).to receive(:add_fields).with(foo: 'bar')
      expect(buffer).not_to receive(:add_message)

      logger.add(0, foo: 'bar')
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
    it 'forwards to the buffer' do
      buffer = instance_double('Rackstash::Buffer')
      expect(logger).to receive(:buffer).and_return(buffer)
      expect(buffer).to receive(:add_exception)

      logger.add_exception(RuntimeError.new)
    end

    it 'implements the same method signature as the Buffer' do
      expect(Rackstash::Buffer.instance_method(:add_exception).parameters)
        .to eql logger.method(:add_exception).parameters
    end

    it 'can be called as #add_error' do
      expect(logger.method(:add_error)).to eql logger.method(:add_exception)
    end
  end

  describe '#push_buffer' do
    it 'pushes a new buffer on the BufferStack' do
      expect(logger.send(:buffer_stack)).to receive(:push).and_call_original
      buffer = logger.push_buffer
      expect(buffer).to be_instance_of Rackstash::Buffer

      expect(buffer).to receive(:add_message)
      logger.info('ping')
    end
  end

  describe '#pop_buffer' do
    it 'pops a buffer from the BufferStack' do
      pushed_buffer = logger.push_buffer

      expect(logger.send(:buffer_stack)).to receive(:pop).and_call_original
      expect(logger.pop_buffer).to equal pushed_buffer
    end

    it 'returns nil of no Buffer can be poped' do
      expect(logger.pop_buffer).to be_nil
    end
  end

  describe '#capture' do
    it 'requires a block' do
      expect { logger.capture }.to raise_error ArgumentError
    end

    it 'adds a new buffer' do
      expect(logger.send(:buffer_stack)).to receive(:push).and_call_original
      expect(logger.send(:buffer_stack)).to receive(:flush_and_pop).and_call_original

      logger.fields['key'] = 'outer'
      logger.capture do
        expect(logger.fields['key']).to be nil
        logger.fields['key'] = 'inner'
      end
      expect(logger.fields['key']).to eql 'outer'
    end

    it 'buffers multiple messages' do
      expect(logger.flows).to receive(:flush).once

      logger.capture do
        logger.add 1, 'Hello World'
        logger.add 0, 'I feel great'
      end
    end

    it 'returns the yielded value' do
      expect(logger.capture { :hello }).to eql :hello
    end

    it 'can use thew #with_buffer alias' do
      expect(logger.method(:with_buffer)).to eql logger.method(:capture)
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
