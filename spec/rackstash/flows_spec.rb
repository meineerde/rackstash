# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/flows'
require 'rackstash/flow'

describe Rackstash::Flows do
  let(:flows) { Rackstash::Flows.new }

  def a_flow
    flow = instance_double('Rackstash::Flow')
    allow(flow).to receive(:is_a?).with(Rackstash::Flow).and_return(true)
    flow
  end

  describe '#initialize' do
    it 'accepts a single flow' do
      list = Rackstash::Flows.new(a_flow)
      expect(list.size).to eql 1
    end

    it 'accepts a list of flows' do
      flows = 3.times.map { a_flow }

      list_with_array = Rackstash::Flows.new(flows)
      expect(list_with_array.size).to eql 3

      list_with_splat = Rackstash::Flows.new(*flows)
      expect(list_with_splat.size).to eql 3
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
      expect(flows.to_a).to eql [nil, nil, nil, flow]
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

  describe '#empty?' do
    it 'is true if empty' do
      expect(flows).to be_empty
      flows << a_flow
      expect(flows).not_to be_empty
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

  describe '#length' do
    it 'returns the number of flows' do
      expect { flows << a_flow}
        .to change { flows.length }.from(0).to(1)
    end

    it 'can use size alias' do
      expect { flows << a_flow}
        .to change { flows.size }.from(0).to(1)
    end
  end

  describe '#to_ary' do
    it 'returns an array' do
      flows << a_flow

      expect(flows.to_a).to be_an_instance_of(::Array)
      expect(flows.to_a).not_to be_empty
    end

    it 'returns a new object each time' do
      array = flows.to_a
      expect(flows.to_a).to eql array
      expect(flows.to_a).not_to equal array

      array << a_flow
      expect(flows.to_a).not_to eql array
    end
  end

  describe '#to_s' do
    it 'returns the array representation' do
      flows << a_flow

      expect(flows.to_s).to eql flows.to_a.to_s
    end
  end
end
