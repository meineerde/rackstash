# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/flow'

describe Rackstash::Flow do
  let(:adapter) { Rackstash::Adapters::Null.new }
  let(:flow) { described_class.new(adapter) }
  let(:event) { {} }

  describe '#initialize' do
    it 'creates an adapter' do
      expect(Rackstash::Adapters).to receive(:[]).with(nil).and_call_original
      expect(described_class.new(nil).adapter).to be_a Rackstash::Adapters::Null
    end

    it 'sets the default encoder from the adapter' do
      encoder = adapter.default_encoder

      expect(adapter).to receive(:default_encoder).and_return(encoder)
      expect(flow.encoder).to equal encoder
    end

    it 'allows to set a custom encoder' do
      encoder = Rackstash::Encoders::Raw.new
      flow = described_class.new(adapter, encoder: encoder)

      expect(flow.encoder).to equal encoder
    end

    it 'creates an empty filter_chain by default' do
      expect(flow.filter_chain).to be_a Rackstash::FilterChain
      expect(flow.filter_chain.length).to eql 0
    end

    it 'accepts filters' do
      filter = -> {}
      flow = described_class.new(adapter, filters: [filter])

      expect(flow.filter_chain[0]).to equal filter
    end

    it 'accepts an error_flow' do
      error_flow = described_class.new(nil)

      flow = described_class.new(adapter, error_flow: error_flow)
      expect(flow.error_flow).to equal error_flow
    end

    it 'yields the adapter if block given' do
      expect { |b| described_class.new(adapter, &b) }
        .to yield_with_args(instance_of(described_class))
    end

    it 'evals the supplied block if it accepts no arguments' do
      context = nil
      flow = described_class.new(adapter) do
        context = self
      end

      expect(context).to equal flow
    end
  end

  describe '#close!' do
    it 'calls adapter#close' do
      expect(adapter).to receive(:close).and_return(true)
      expect(flow.close).to be nil
    end
  end

  describe '#close' do
    it 'calls #close!' do
      expect(flow).to receive(:close!)
      flow.close
    end

    it 'rescues any exception thrown by the adapter' do
      error_flow = instance_double(described_class)
      expect(error_flow).to receive(:write!)
        .with(
          'error' => 'RuntimeError',
          'error_message' => 'ERROR',
          'error_trace' => instance_of(String),

          'tags' => [],
          'message' => [instance_of(Rackstash::Message)],

          '@timestamp' => instance_of(Time)
        )
      expect(flow).to receive(:error_flow).and_return(error_flow)

      expect(flow).to receive(:close!).and_raise('ERROR')
      expect(flow.close).to be nil
    end

    it 'rescues errors thrown by the error_flow' do
      error_flow = instance_double(described_class)
      expect(error_flow).to receive(:write!).and_raise('DOUBLE ERROR')
      expect(flow).to receive(:error_flow).and_return(error_flow)

      expect(flow).to receive(:close!).and_raise('ERROR')
      expect(flow.close).to be nil
    end
  end

  describe '#encoder' do
    it 'returns the current encoder' do
      expect(flow.encoder).to respond_to(:encode)
      expect(flow.encoder(nil)).to respond_to(:encode)
    end

    it 'allows to set a new encoder' do
      encoder = Rackstash::Encoders::JSON.new
      expect(flow.encoder(encoder)).to equal encoder

      # The encoder is persisted and is returned afterwards
      expect(flow.encoder).to equal encoder
    end

    it 'rejects invalid encoders' do
      expect { flow.encoder :foo }.to raise_error TypeError
      expect { flow.encoder 23 }.to raise_error TypeError
      expect { flow.encoder true }.to raise_error TypeError
      expect { flow.encoder false }.to raise_error TypeError
      expect { flow.encoder -> {} }.to raise_error TypeError
    end
  end

  describe '#error_flow' do
    it 'returns the global error_flow by default' do
      expect(Rackstash).to receive(:error_flow).and_call_original
      expect(flow.error_flow).to be_instance_of described_class
    end

    it 'can set a custom error_flow' do
      error_flow = described_class.new(adapter)
      expect(flow.error_flow(error_flow)).to equal error_flow

      # The error_flow is persisted and is returned afterwards
      expect(flow.error_flow).to equal error_flow
    end

    it 'creates a flow object when setting a value' do
      # load the flow helper so that the receive test below counts correctly
      flow = self.flow

      expect(described_class).to receive(:new).with(adapter).and_call_original
      new_flow = flow.error_flow(adapter)

      expect(flow.error_flow).to be_instance_of described_class
      expect(flow.error_flow).to equal new_flow
    end
  end

  describe '#filter_after' do
    before(:each) do
      flow.filter_chain << ->(event) {}
    end

    it 'calls FilterChain#insert_after' do
      expect(flow.filter_chain).to receive(:insert_after).twice.and_call_original

      expect(flow.filter_after(0, ->(event) { event })).to equal flow
      expect(flow.filter_after(0) { |event| event }).to equal flow

      expect(flow.filter_chain.size).to eql 3
    end
  end

  describe '#filter_append' do
    it 'calls FilterChain#append' do
      expect(flow.filter_chain).to receive(:append).twice.and_call_original

      expect(flow.filter_append(->(event) { event })).to equal flow
      expect(flow.filter_append { |event| event }).to equal flow

      expect(flow.filter_chain.size).to eql 2
    end

    it 'can use the #filter alias' do
      expect(flow.method(:filter)).to eql flow.method(:filter_append)
    end
  end

  describe '#filter_delete' do
    before(:each) do
      flow.filter_chain << ->(event) {}
    end

    it 'calls FilterChain#delete' do
      expect(flow.filter_chain).to receive(:delete).once.and_call_original

      expect(flow.filter_delete(0)).to be_a Proc
      expect(flow.filter_chain.size).to eql 0
    end
  end

  describe '#filter_before' do
    before(:each) do
      flow.filter_chain << ->(event) {}
    end

    it 'calls FilterChain#insert_before' do
      expect(flow.filter_chain).to receive(:insert_before).twice.and_call_original

      expect(flow.filter_before(0, ->(event) { event })).to equal flow
      expect(flow.filter_before(0) { |event| event }).to equal flow

      expect(flow.filter_chain.size).to eql 3
    end
  end

  describe '#filter_unshift' do
    it 'calls FilterChain#unshift' do
      expect(flow.filter_chain).to receive(:unshift).twice.and_call_original

      expect(flow.filter_unshift(->(event) { event })).to equal flow
      expect(flow.filter_unshift { |event| event }).to equal flow

      expect(flow.filter_chain.size).to eql 2
    end

    it 'can use the #filter_prepend alias' do
      expect(flow.method(:filter_prepend)).to eql flow.method(:filter_unshift)
    end
  end

  describe '#reopen' do
    it 'calls adapter#reopen' do
      expect(adapter).to receive(:reopen).and_return(true)
      expect(flow.reopen).to be nil
    end
  end

  describe '#reopen' do
    it 'calls #reopen!' do
      expect(flow).to receive(:reopen!)
      flow.reopen
    end

    it 'rescues any exception thrown by the adapter' do
      error_flow = instance_double(described_class)
      expect(error_flow).to receive(:write!)
        .with(
          'error' => 'RuntimeError',
          'error_message' => 'ERROR',
          'error_trace' => instance_of(String),

          'tags' => [],
          'message' => [instance_of(Rackstash::Message)],

          '@timestamp' => instance_of(Time)
        )
      expect(flow).to receive(:error_flow).and_return(error_flow)

      expect(flow).to receive(:reopen!).and_raise('ERROR')
      expect(flow.reopen).to be nil
    end

    it 'rescues errors thrown by the error_flow' do
      error_flow = instance_double(described_class)
      expect(error_flow).to receive(:write!).and_raise('DOUBLE ERROR')
      expect(flow).to receive(:error_flow).and_return(error_flow)

      expect(flow).to receive(:reopen!).and_raise('ERROR')
      expect(flow.reopen).to be nil
    end
  end

  describe '#write!' do
    it 'calls the filter_chain' do
      expect(flow.filter_chain).to receive(:call)
      flow.write!(event)
    end

    it 'aborts if the filter_chain returns false' do
      expect(flow.filter_chain).to receive(:call).and_return(false)

      expect(flow.encoder).not_to receive(:encode)
      expect(flow.adapter).not_to receive(:write)
      flow.write!(event)
    end

    it 'encodes the event' do
      expect(flow.encoder).to receive(:encode).with(event)
      flow.write!(event)
    end

    it 'writes the encoded event to the adapter' do
      expect(flow.encoder).to receive(:encode).and_return 'encoded'
      expect(flow.adapter).to receive(:write).with('encoded').and_call_original

      expect(flow.write!(event)).to be true
    end

    it 'writes the encoded event to the adapter' do
      expect(flow.encoder).to receive(:encode).and_return 'encoded'
      expect(flow.adapter).to receive(:write).with('encoded').and_call_original

      expect(flow.write!(event)).to be true
    end
  end

  describe '#write' do
    it 'calls #write!' do
      expect(flow).to receive(:write!).with(event)
      flow.write(event)
    end

    it 'rescues any exception thrown by the adapter' do
      error_flow = instance_double(described_class)
      expect(error_flow).to receive(:write!)
        .with(
          'error' => 'RuntimeError',
          'error_message' => 'ERROR',
          'error_trace' => instance_of(String),

          'tags' => [],
          'message' => [instance_of(Rackstash::Message)],

          '@timestamp' => instance_of(Time)
        )
      expect(flow).to receive(:error_flow).and_return(error_flow)

      expect(flow).to receive(:write!).and_raise('ERROR')
      expect(flow.write(event)).to be false
    end

    it 'rescues errors thrown by the error_flow' do
      error_flow = instance_double(described_class)
      expect(error_flow).to receive(:write!).and_raise('DOUBLE ERROR')
      expect(flow).to receive(:error_flow).and_return(error_flow)

      expect(flow).to receive(:write!).and_raise('ERROR')
      expect(flow.write(event)).to be false
    end
  end
end
