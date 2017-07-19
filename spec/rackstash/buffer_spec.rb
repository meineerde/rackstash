# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/buffer'

describe Rackstash::Buffer do
  let(:buffer_options) { {} }
  let(:sink) { instance_double(Rackstash::Sink) }
  let(:buffer) { described_class.new(sink, **buffer_options) }

  describe '#allow_empty?' do
    it 'defaults to false' do
      expect(buffer.allow_empty?).to be false
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
      expect(buffer.timestamp).to eql '2016-10-17T10:37:00.000Z'
    end

    context 'when buffering?' do
      before do
        buffer_options[:buffering] = true
      end

      it 'does not call #flush' do
        expect(buffer).not_to receive(:flush)
        buffer.add_message double(message: 'Hello World!', time: Time.now)
      end

      it 'does not call #clear' do
        expect(buffer).not_to receive(:clear)
        buffer.add_message double(message: 'Hello World!', time: Time.now)
        expect(buffer.messages.count).to eql 1
      end
    end

    context 'when not buffering?' do
      before do
        buffer_options[:buffering] = false
      end

      it 'calls #flush' do
        expect(buffer).to receive(:flush)
        buffer.add_message double(message: 'Hello World!', time: Time.now)
      end

      it 'calls #clear' do
        allow(buffer).to receive(:flush)
        expect(buffer).to receive(:clear).and_call_original
        buffer.add_message double(message: 'Hello World!', time: Time.now)
        expect(buffer.messages.count).to eql 0
        expect(buffer.pending?).to be false
      end
    end
  end

  describe '#buffering?' do
    it 'defaults to false' do
      expect(buffer.buffering?).to be true
    end

    it 'can be overwritten in initialize' do
      buffer_options[:buffering] = false
      expect(buffer.buffering?).to be false
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
      expect(buffer.timestamp).to eql '2016-10-17T13:37:00.000Z'

      buffer.clear

      expect(Time).to receive(:now).and_call_original
      expect(buffer.timestamp).not_to eql '2016-10-17T13:37:00.000Z'
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
      before do
        buffer.add_message double(message: 'Hello World!', time: Time.now)

        # We might call Buffer#flush during the following tests
        allow(sink).to receive(:flush).with(buffer).once
      end

      it 'flushes the buffer to the sink' do
        expect(sink).to receive(:flush).with(buffer).once
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
      it 'does not flushes the buffer to the sink' do
        expect(sink).not_to receive(:flush)
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

    context 'allow_empty == true' do
      before do
        buffer_options[:allow_empty] = true
        expect(buffer.allow_empty?).to be true
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
    end

    context 'allow_empty == false' do
      before do
        buffer_options[:allow_empty] = false
        expect(buffer.allow_empty?).to be false
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

      expect(Time).to receive(:now).once.and_return(now)
      expect(now).to receive(:utc).once.and_return(now.utc)

      expect(buffer.timestamp).to eql '2016-10-17T10:37:00.000Z'
      expect(buffer.timestamp).to eql '2016-10-17T10:37:00.000Z'
    end

    it 'initializes @timestamp with the passed time' do
      now = Time.parse('2016-10-17 13:37:00 +03:00')

      expect(Time).not_to receive(:now)
      expect(buffer.timestamp(now)).to eql '2016-10-17T10:37:00.000Z'
      expect(buffer.timestamp).to eql '2016-10-17T10:37:00.000Z'
    end

    it 'does not overwrites an already set timestamp' do
      first = Time.parse('2016-10-17 10:10:10 +03:00')
      second = Time.parse('2016-10-17 20:20:20 +03:00')

      buffer.timestamp(first)
      expect(buffer.timestamp).to eql '2016-10-17T07:10:10.000Z'

      buffer.timestamp
      expect(buffer.timestamp).to eql '2016-10-17T07:10:10.000Z'

      buffer.timestamp(second)
      expect(buffer.timestamp).to eql '2016-10-17T07:10:10.000Z'
    end
  end
end
