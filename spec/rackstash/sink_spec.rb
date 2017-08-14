# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/sink'

require 'rackstash/buffer'
require 'rackstash/flows'
require 'rackstash/flow'

describe Rackstash::Sink do
  def a_flow
    flow = instance_double('Rackstash::Flow')
    allow(flow).to receive(:is_a?).with(Rackstash::Flow).and_return(true)
    flow
  end

  let(:flow) { a_flow }
  let(:sink) { described_class.new(flow) }

  describe 'initialize' do
    # We deliberately use the real Rackstash::Flows class here to server as an
    # integration test
    it 'wraps a single flow in a flows list' do
      expect(Rackstash::Flows).to receive(:new).with(flow)
        .and_call_original

      sink = described_class.new(flow)
      expect(sink.flows).to be_a Rackstash::Flows
      expect(sink.flows.to_a).to eql [flow]
    end

    it 'wraps multiple flows in a flows list' do
      flows = [a_flow, a_flow]

      expect(Rackstash::Flows).to receive(:new).with(flows)
        .and_call_original
      sink = described_class.new(flows)

      expect(sink.flows).to be_a Rackstash::Flows
      expect(sink.flows.to_a).to eql flows
    end
  end

  describe '#default_fields' do
    it 'can set a proc' do
      a_proc = proc { nil }
      expect(a_proc).not_to receive(:call)

      sink.default_fields = a_proc
      expect(sink.default_fields).to equal a_proc
    end

    it 'can set a Hash' do
      hash = { foo: :bar }
      sink.default_fields = hash

      expect(sink.default_fields).to equal hash
    end

    it 'can set a Hash-like object' do
      hash_alike = double('hash')
      expect(hash_alike).to receive(:to_hash).and_return(foo: :bar)

      sink.default_fields = hash_alike
      expect(sink.default_fields).to eql(foo: :bar)
      expect(sink.default_fields).not_to equal hash_alike
    end

    it 'refuses invalid fields' do
      expect { sink.default_fields = nil }.to raise_error TypeError
      expect { sink.default_fields = 42 }.to raise_error TypeError
      expect { sink.default_fields = ['foo'] }.to raise_error TypeError
    end
  end

  describe '#default_tags' do
    it 'can set a proc' do
      tags = proc { nil }
      expect(tags).not_to receive(:call)

      sink.default_tags = tags
      expect(sink.default_tags).to equal tags
    end

    it 'can set an Array' do
      array = [:foo, 'bar']
      sink.default_tags = array

      expect(sink.default_tags).to equal array
    end

    it 'can set an Array-like object' do
      array_alike = double('array')
      expect(array_alike).to receive(:to_ary).and_return([:foo])

      sink.default_tags = array_alike
      expect(sink.default_tags).to eql [:foo]
      expect(sink.default_tags).not_to equal array_alike
    end

    it 'refuses invalid fields' do
      expect { sink.default_tags = nil }.to raise_error TypeError
      expect { sink.default_tags = 42 }.to raise_error TypeError
      expect { sink.default_tags = { foo: :bar } }.to raise_error TypeError
    end
  end

  describe '#close' do
    let(:flow) { [a_flow, a_flow] }

    it 'calls close on all flows' do
      expect(flow).to all receive(:close)
      expect(sink.close).to be_nil
    end
  end

  describe '#reopen' do
    let(:flow) { [a_flow, a_flow] }

    it 'calls reopen on all flows' do
      expect(flow).to all receive(:reopen)
      expect(sink.reopen).to be_nil
    end
  end

  describe '#write' do
    let(:flows) {
      [a_flow, a_flow].each do |flow|
        allow(flow).to receive(:write)
      end
    }
    let(:sink) { described_class.new(flows) }
    let(:buffer) { Rackstash::Buffer.new(sink) }

    it 'merges default_fields and default_tags' do
      expect(buffer).to receive(:to_event).with(fields: {}, tags: [])
      sink.write(buffer)
    end

    it 'flushes the buffer to all flows' do
      event_spec = {
        'message' => [],
        'tags' => [],
        '@timestamp' => instance_of(String)
      }

      # only the first event is duplicated
      expect(sink).to receive(:deep_dup_event).with(event_spec).and_call_original.ordered
      event_spec.each_value do |arg|
        expect(sink).to receive(:deep_dup_event).with(arg).and_call_original.ordered
      end

      # During flush, we create a single event, duplicate it and write each to
      # each of the flows.
      expect(flows).to all receive(:write).with(event_spec)
      sink.write(buffer)
    end
  end
end
