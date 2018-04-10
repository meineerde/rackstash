# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/buffer'

RSpec.describe Rackstash::Buffer do
  let(:buffer_options) { {} }

  let(:flows) {
    instance_double(Rackstash::Flows).tap do |flows|
      allow(flows).to receive(:flush)
      allow(flows).to receive(:auto_flush)
    end
  }

  let(:buffer) { described_class.new(flows, **buffer_options) }

  describe '#allow_silent?' do
    it 'defaults to true' do
      expect(buffer.allow_silent?).to be true
    end
  end

  describe '#add_exception' do
    it 'adds the exception fields' do
      begin
        raise 'My Error'
      rescue RuntimeError => e
        buffer.add_exception(e)
      end

      expect(buffer.fields['error']).to eql 'RuntimeError'
      expect(buffer.fields['error_message']).to eql 'My Error'
      expect(buffer.fields['error_trace']).to match %r{\A#{__FILE__}:#{__LINE__ - 7}:in}
    end

    it 'does not require a backtrace' do
      buffer.add_exception(StandardError.new('Error'))

      expect(buffer.fields['error']).to eql 'StandardError'
      expect(buffer.fields['error_message']).to eql 'Error'
      expect(buffer.fields['error_trace']).to eql ''
    end

    context 'with force: true' do
      it 'overwrites exceptions' do
        begin
          raise 'Error'
        rescue RuntimeError => first
          buffer.add_exception(first, force: true)
        end

        begin
          raise TypeError, 'Another Error'
        rescue TypeError => second
          buffer.add_exception(second, force: true)
        end

        expect(buffer.fields['error']).to eql 'TypeError'
        expect(buffer.fields['error_message']).to eql 'Another Error'
        expect(buffer.fields['error_trace']).to match %r{\A#{__FILE__}:#{__LINE__ - 7}:in}
      end
    end

    context 'with force: false' do
      it 'does not overwrite exceptions' do
        buffer.fields['error'] = 'Something is wrong'

        begin
          raise TypeError, 'Error'
        rescue TypeError => second
          buffer.add_exception(second, force: false)
        end

        expect(buffer.fields['error']).to eql 'Something is wrong'
        expect(buffer.fields['error_message']).to be_nil
        expect(buffer.fields['error_trace']).to be_nil
      end
    end
  end

  describe '#add_fields' do
    it 'deep-merges fields' do
      buffer.add_fields(foo: :bar, number: 123)

      expect(buffer.fields['foo']).to eql 'bar'
      expect(buffer.fields['number']).to eql 123
    end

    it 'overwrites fields' do
      buffer.fields['foo'] = 'initial'
      buffer.add_fields(foo: 'overwritten')

      expect(buffer.fields['foo']).to eql 'overwritten'
    end

    it 'raises ArgumentError when trying to set a forbidden key' do
      expect { buffer.add_fields(message: 'oh no!') }.to raise_error ArgumentError
    end

    it 'sets the timestamp' do
      expect(buffer).to receive(:timestamp)
      buffer.add_fields(key: 'value')
    end

    context 'when allow_silent?' do
      before do
        buffer_options[:allow_silent] = true
      end

      it 'sets pending? to true' do
        buffer.add_fields(key: 'value')
        expect(buffer.pending?).to be true
      end

      it 'calls auto_flush' do
        expect(flows).to receive(:auto_flush)
        buffer.add_fields(key: 'value')
      end
    end

    context 'when not allow_silent?' do
      before do
        buffer_options[:allow_silent] = false
      end

      it 'does not set pending? to true' do
        buffer.add_fields(key: 'value')
        expect(buffer.pending?).to be false
      end

      it 'calls auto_flush' do
        expect(flows).to receive(:auto_flush)
        buffer.add_fields(key: 'value')
      end
    end

    context 'with buffering: true' do
      before do
        buffer_options[:buffering] = true
      end

      it 'does not flush the buffer' do
        expect(flows).not_to receive(:flush)
        # We always auto_flush buffers to send the newly added fields to
        # interested flows
        expect(flows).to receive(:auto_flush)

        buffer.add_fields(key: 'value')
      end

      it 'does not clear the buffer' do
        expect(buffer).not_to receive(:clear)
        buffer.add_fields(key: 'value')

        expect(buffer.fields['key']).to eql 'value'
        expect(buffer.pending?).to be true
      end
    end

    context 'with buffering: false' do
      before do
        buffer_options[:buffering] = false
      end

      it 'flushes the buffer' do
        expect(flows).to receive(:flush)
        expect(flows).to receive(:auto_flush)

        buffer.add_fields(key: 'value')
      end

      it 'clears the buffer' do
        buffer.add_fields(key: 'value')

        expect(buffer.fields).to be_empty
        expect(buffer.pending?).to be false
      end
    end

    it 'returns the given value' do
      fields = { key: 'value' }
      expect(buffer.add_fields(fields)).to equal fields
    end
  end

  describe '#add_message' do
    it 'adds a message to the buffer' do
      msg = double(message: 'Hello World', time: Time.now)
      expect(buffer.add_message(msg)).to equal msg

      expect(buffer.messages).to eql [msg]
    end

    it 'sets the timestamp' do
      time = Time.parse('2016-10-17 13:37:00 +03:00')
      msg = double(message: 'Hello World', time: time)

      buffer.add_message msg
      expect(buffer.timestamp).to eql time.getutc
    end

    context 'with buffering: true' do
      before do
        buffer_options[:buffering] = true
      end

      it 'does not flush the buffer' do
        expect(flows).not_to receive(:flush)
        buffer.add_message double(message: 'Hello World!', time: Time.now)
      end

      it 'retains messages' do
        buffer.add_message double(message: 'Hello World!', time: Time.now)
        expect(buffer.messages.count).to eql 1
      end
    end

    context 'with buffering: false' do
      before do
        buffer_options[:buffering] = false
      end

      it 'flushes the buffer' do
        expect(flows).to receive(:flush)
        buffer.add_message double(message: 'Hello World!', time: Time.now)
      end

      it 'clears messages' do
        buffer.add_message double(message: 'Hello World!', time: Time.now)

        expect(buffer.messages.count).to eql 0
        expect(buffer.pending?).to be false
      end
    end
  end

  describe '#buffering' do
    it 'defaults to true' do
      expect(buffer.buffering?).to eql true
    end

    it 'can be set to true' do
      expect(described_class.new(flows, buffering: true).buffering?).to be true
      expect(described_class.new(flows, buffering: 'whatever').buffering?).to be true
    end

    it 'can be set to false' do
      expect(described_class.new(flows, buffering: false).buffering?).to be false
      expect(described_class.new(flows, buffering: nil).buffering?).to be false
    end
  end

  describe '#clear' do
    it 'removes all fields and tags' do
      buffer.fields['foo'] = 'bar'
      buffer.tag 'super_important'

      buffer.clear
      expect(buffer.tags).to be_empty
      expect(buffer.fields).to be_empty
    end

    it 'clears the message buffer' do
      buffer.add_message double(message: 'Hello World!', time: Time.now)
      buffer.clear

      expect(buffer.messages).to eql []
    end

    it 'removes the pending flag' do
      buffer.add_message double(message: 'raw', time: Time.now)

      expect(buffer.pending?).to be true
      buffer.clear
      expect(buffer.pending?).to be false
    end

    it 'resets the timestamp' do
      buffer.timestamp(Time.parse('2016-10-17 15:37:00 +02:00'))
      expect(buffer.timestamp).to eql Time.utc(2016, 10, 17, 13, 37, 0)

      buffer.clear

      expect(Time).to receive(:now).and_call_original
      expect(buffer.timestamp).not_to eql Time.utc(2016, 10, 17, 13, 37, 0)
    end
  end

  describe '#fields' do
    it 'returns a Rackstash::Fields::Hash' do
      expect(buffer.fields).to be_a Rackstash::Fields::Hash

      # Always returns the same fields object
      expect(buffer.fields).to equal buffer.fields
    end

    it 'forbids setting reserved fields' do
      expect { buffer.fields['message'] = 'test' } .to raise_error ArgumentError
      expect { buffer.fields['tags'] = 'test' } .to raise_error ArgumentError
      expect { buffer.fields['@version'] = 'test' } .to raise_error ArgumentError
      expect { buffer.fields['@timestamp'] = 'test' } .to raise_error ArgumentError
    end
  end

  describe '#flush' do
    before do
      # Create a buffering Buffer to prevent #add_message from flushing the
      # Buffer on its own.
      buffer_options[:buffering] = true
    end

    context 'when pending?' do
      let(:time) { Time.parse('2016-10-17 15:37:00 +02:00') }
      let(:message) { double(message: 'Hello World!', time: time) }
      let(:event) {
        {
          'message' => [message],
          'tags' => [],
          '@timestamp' => time
        }
      }

      before do
        buffer.add_message(message)

        # We might call Buffer#flush during the following tests
        allow(flows).to receive(:flush).with(event).once
      end

      it 'flushes the buffer to the flows' do
        expect(flows).to receive(:flush).with(event).once
        buffer.flush
      end

      it 'does not clear the buffer' do
        expect(buffer).not_to receive(:clear)
        buffer.flush
        expect(buffer.messages.count).to eql 1
      end

      it 'returns the buffer' do
        expect(buffer.flush).to equal buffer
      end
    end

    context 'when not pending?' do
      it 'does not flushes the buffer to the flows' do
        expect(flows).not_to receive(:flush)
        buffer.flush
      end

      it 'does not clear the buffer' do
        expect(buffer).not_to receive(:clear)
        buffer.flush
      end

      it 'returns nil' do
        expect(buffer.flush).to be nil
      end
    end
  end

  describe '#messages' do
    it 'returns an array of messages' do
      msg = double(message: 'Hello World', time: Time.now)
      buffer.add_message(msg)

      expect(buffer.messages).to eql [msg]
    end

    it 'returns a new array each time' do
      expect(buffer.messages).not_to equal buffer.messages

      expect(buffer.messages).to eql []
      buffer.messages << 'invalid'
      expect(buffer.messages).to eql []
    end
  end

  describe '#pending?' do
    it 'sets pending when adding a message' do
      buffer.add_message double(message: 'some message', time: Time.now)
      expect(buffer.pending?).to be true
    end

    context 'with allow_silent: true' do
      before do
        buffer_options[:allow_silent] = true
        expect(buffer.allow_silent?).to be true
      end

      it 'defaults to false' do
        expect(buffer.pending?).to be false
      end

      it 'is true if there are any fields' do
        buffer.fields['alice'] = 'bob'
        expect(buffer.pending?).to be true
      end

      it 'is true if there are any tags' do
        buffer.tags << 'alice'
        expect(buffer.pending?).to be true
      end

      it 'is true if the timestamp was set' do
        buffer.timestamp
        expect(buffer.pending?).to be true
      end
    end

    context 'with allow_silent: false' do
      before do
        buffer_options[:allow_silent] = false
        expect(buffer.allow_silent?).to be false
      end

      it 'defaults to false' do
        expect(buffer.pending?).to be false
      end

      it 'ignores fields' do
        buffer.fields['alice'] = 'bob'
        expect(buffer.pending?).to be false
      end

      it 'ignores tags' do
        buffer.tags << 'alice'
        expect(buffer.pending?).to be false
      end

      it 'ignores the timestamp' do
        buffer.timestamp
        expect(buffer.pending?).to be false
      end
    end
  end

  describe '#tag' do
    it 'adds tags' do
      buffer.tag # don't fail with empty argument list
      buffer.tag 'tag1', 'tag2'
      expect(buffer.tags).to contain_exactly('tag1', 'tag2')
    end

    it 'adds tags only once' do
      buffer.tag 'hello'
      buffer.tag :hello

      expect(buffer.tags).to contain_exactly('hello')
    end

    it 'stringifys tags and expands procs' do
      buffer.tag 123, :symbol, -> { :proc }
      expect(buffer.tags).to contain_exactly('123', 'symbol', 'proc')
    end

    it 'does not set blank tags' do
      buffer.tag 'tag', nil, [], '', {}
      expect(buffer.tags).to contain_exactly('tag')
    end

    it 'sets the timestamp' do
      expect(buffer).to receive(:timestamp)
      buffer.tag('hello')
    end

    describe 'when passing procs' do
      let(:struct) {
        Struct.new(:value) do
          def to_s
            value
          end
        end
      }

      let(:object) {
        struct.new('Hello')
      }

      it 'expands single-value proc objects' do
        buffer.tag(-> { self }, scope: object)
        expect(buffer.tags).to contain_exactly('Hello')
      end

      it 'expands multi-value proc objects' do
        buffer.tag(-> { [[self, 'foobar'], 123] }, scope: object)
        expect(buffer.tags).to contain_exactly('Hello', 'foobar', '123')
      end
    end
  end

  describe '#timestamp' do
    it 'initializes @timestamp to Time.now.utc' do
      now = Time.parse('2016-10-17 13:37:00 +03:00')
      now_utc = Time.utc(2016, 10, 17, 10, 37, 0).freeze

      expect(Time).to receive(:now).once.and_return(now)
      expect(now).to receive(:utc).once.and_return(now_utc)

      expect(buffer.timestamp).to equal now_utc
      expect(buffer.timestamp).to equal now_utc
    end

    it 'initializes @timestamp with the passed time' do
      now = Time.parse('2016-10-17 13:37:00 +03:00')
      now_utc = Time.utc(2016, 10, 17, 10, 37, 0).freeze

      expect(Time).not_to receive(:now)
      expect(buffer.timestamp(now)).to eql now_utc
      expect(buffer.timestamp).to eql now_utc
    end

    it 'does not overwrites an already set timestamp' do
      first = Time.parse('2016-10-17 10:10:10 +03:00')
      second = Time.parse('2016-10-17 20:20:20 +03:00')

      buffer.timestamp(first)
      expect(buffer.timestamp).to eql first.getutc

      buffer.timestamp
      expect(buffer.timestamp).to eql first.getutc

      buffer.timestamp(second)
      expect(buffer.timestamp).to eql first.getutc
    end
  end

  describe '#event' do
    it 'creates an event hash' do
      message = double(message: 'Hello World', time: Time.now)
      allow(message)
      buffer.add_message(message)
      buffer.fields[:foo] = 'bar'
      buffer.tags << 'some_tag'

      expect(buffer.event).to match(
        'foo' => 'bar',
        'message' => [message],
        'tags' => ['some_tag'],
        '@timestamp' => instance_of(Time)
      )
    end
  end
end
