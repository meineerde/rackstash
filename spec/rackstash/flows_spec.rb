# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/flows'
require 'rackstash/flow'

describe Rackstash::Flows do
  let(:flows) { described_class.new }

  def a_flow
    flow = instance_double('Rackstash::Flow')
    allow(flow).to receive(:is_a?).with(Rackstash::Flow).and_return(true)
    flow
  end

  describe '#initialize' do
    it 'accepts a single flow' do
      list = described_class.new(a_flow)
      expect(list.size).to eql 1
    end

    it 'accepts a list of flows' do
      raw_flows = Array.new(3) { a_flow }

      list_with_splat = described_class.new(*raw_flows)
      expect(list_with_splat.size).to eql 3
    end

    it 'creates flows if necessary' do
      flow_class = class_double('Rackstash::Flow').as_stubbed_const
      expect(flow_class).to receive(:new).with(:dummy).and_return(a_flow)

      described_class.new(:dummy)
    end
  end

  describe '#<<' do
    let(:flow) { a_flow }

    it 'adds a new flow at the end of the list' do
      expect(flows.size).to eql 0
      flows << flow
      expect(flows.size).to eql 1
      expect(flows[0]).to equal flow
    end

    it 'tries to find a matching flow' do
      wrapped = Object.new
      flow = Object.new

      flow_class = class_double('Rackstash::Flow').as_stubbed_const
      expect(flow_class).to receive(:new).with(wrapped).and_return(flow)

      expect(flows.size).to eql 0
      flows << wrapped
      expect(flows.size).to eql 1
      expect(flows[0]).to equal flow
    end

    it 'can use the #add alias' do
      expect(flows.size).to eql 0
      flows.add flow
      expect(flows.size).to eql 1
      expect(flows[0]).to equal flow
    end
  end

  describe '#[]' do
    let(:flow) { a_flow }

    it 'returns the index flow' do
      flows << flow
      expect(flows[0]).to equal flow
      expect(flows[1]).to be_nil
    end
  end

  describe '#[]=' do
    it 'sets a flow' do
      original_flow = a_flow
      new_flow = a_flow

      flows << original_flow
      expect(flows[0]).to equal original_flow

      flows[0] = new_flow
      expect(flows[0]).to equal new_flow
    end

    it 'adds nil flows if necessary' do
      flow = a_flow
      flows[3] = flow
      expect(flows.length).to eql 4
    end

    it 'tries to find a matching flow' do
      wrapped = Object.new
      flow = Object.new

      flow_class = class_double('Rackstash::Flow').as_stubbed_const
      expect(flow_class).to receive(:new).with(wrapped).and_return(flow)

      flows[0] = wrapped
      expect(flows[0]).to equal flow
    end
  end

  describe '#close' do
    it 'calls close on all flows' do
      [a_flow, a_flow].each do |flow|
        expect(flow).to receive(:close)
        flows << flow
      end

      expect(flows.close).to be_nil
    end
  end

  describe '#dup' do
    it 'dups the flows' do
      flows << a_flow
      copied = flows.dup

      expect(copied).to be_instance_of described_class
      expect(copied.length).to eql 1
      expect(copied).to_not equal flows
    end

    it 'separates the flows' do
      flows << a_flow

      copied = flows.dup
      copied << a_flow

      expect(copied.first).to equal flows.first

      expect(flows.length).to eql 1
      expect(copied.length).to eql 2
    end
  end

  describe '#freeze' do
    it 'freezes the object' do
      expect(flows.freeze).to equal flows
      expect(flows).to be_frozen
    end

    it 'denies all further changes' do
      flows.freeze
      expect { flows << a_flow }.to raise_error(RuntimeError)
    end
  end

  describe '#reopen' do
    it 'calls reopen on all flows' do
      [a_flow, a_flow].each do |flow|
        expect(flow).to receive(:reopen)
        flows << flow
      end

      expect(flows.reopen).to be_nil
    end
  end

  describe '#each' do
    it 'yield each flow' do
      flow1 = a_flow
      flow2 = a_flow

      flows << flow1
      flows << flow2

      expect { |b| flows.each(&b) }.to yield_successive_args(flow1, flow2)
    end

    it 'does not yield nil values' do
      flows[3] = a_flow
      expect { |b| flows.each(&b) }.to yield_control.once
    end

    it 'returns the flow if a block was provided' do
      flows << a_flow
      expect(flows.each {}).to equal flows
    end

    it 'returns an Enumerator if no block was provided' do
      flows << a_flow
      expect(flows.each).to be_instance_of Enumerator
    end

    it 'operators on a copy of the internal data' do
      yielded = 0
      flows << a_flow

      flows.each do |flow|
        yielded += 1
        flows[1] = flow
      end

      expect(yielded).to eql 1
    end
  end

  describe '#empty?' do
    it 'is true if empty' do
      expect(flows).to be_empty
      flows << a_flow
      expect(flows).not_to be_empty
    end
  end

  describe '#first' do
    it 'gets the first flow' do
      expect(flows.first).to be_nil

      flows << a_flow
      expect(flows.first).to equal flows[0]
    end

    it 'gets a number of flows' do
      flow_list = [a_flow, a_flow, a_flow]
      flow_list.each do |flow|
        flows << flow
      end

      expect(flows.first(2)).to eql flow_list[0, 2]
      expect(flows.first(4)).to eql flow_list
    end
  end

  describe '#inspect' do
    it 'formats the object' do
      expect(flows).to receive(:to_s).and_return('["<flow>"]')
      expect(flows.inspect).to(
        match %r{\A#<Rackstash::Flows:0x[a-f0-9]+ \["<flow>"\]>\z}
      )
    end
  end

  describe '#last' do
    it 'gets the last flow' do
      expect(flows.last).to be_nil

      flows << a_flow
      expect(flows.last).to equal flows[0]
    end

    it 'gets a number of flows' do
      flow_list = [a_flow, a_flow, a_flow]
      flow_list.each do |flow|
        flows << flow
      end

      expect(flows.last(2)).to eql flow_list[1, 2]
      expect(flows.last(4)).to eql flow_list
    end
  end

  describe '#length' do
    it 'returns the number of flows' do
      expect { flows << a_flow }
        .to change { flows.length }.from(0).to(1)
    end

    it 'can use size alias' do
      expect { flows << a_flow }
        .to change { flows.size }.from(0).to(1)
    end
  end

  describe '#to_ary' do
    it 'returns an array' do
      flows << a_flow

      expect(flows.to_ary).to be_an_instance_of(::Array)
      expect(flows.to_ary).not_to be_empty
    end

    it 'returns a new object each time' do
      array = flows.to_ary
      expect(flows.to_ary).to eql array
      expect(flows.to_ary).not_to equal array

      array << a_flow
      expect(flows.to_ary).not_to eql array
    end

    it 'does not include nil elements' do
      flow = a_flow
      flows[3] = flow

      expect(flows.size).to eql 4
      expect(flows.to_ary).to eql [flow]
    end

    it 'can use to_a alias' do
      flows << a_flow

      expect(flows.to_a).to be_an_instance_of(::Array)
      expect(flows.to_a).not_to be_empty
    end
  end

  describe '#to_s' do
    it 'returns the array representation' do
      flows << a_flow

      expect(flows.to_s).to eql flows.to_a.to_s
    end
  end

  describe '#write' do
    it 'flushes the buffer to all flows' do
      event_spec = {
        'foo' => 'bar',
        'tags' => [],
        '@timestamp' => instance_of(Time)
      }

      [a_flow, a_flow].each do |flow|
        expect(flow).to receive(:write).with(event_spec)
        flows << flow
      end

      # only the first event is duplicated
      expect(flows).to receive(:deep_dup_event).with(event_spec).and_call_original.ordered
      event_spec.each_value do |arg|
        expect(flows).to receive(:deep_dup_event).with(arg).and_call_original.ordered
      end

      # During flush, we create a single event, duplicate it and write each to
      # each of the flows.
      flows.write('foo' => 'bar', 'tags' => [], '@timestamp' => Time.now.utc)
    end
  end
end
