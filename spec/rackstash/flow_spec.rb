# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/flow'

RSpec.describe Rackstash::Flow do
  let(:adapter) { Rackstash::Adapter::Null.new }
  let(:flow_args) { {} }
  let(:flow) { described_class.new(adapter, **flow_args) }
  let(:event) { {} }

  after(:each) do
    # ensure that the asynchonous call was actually performed
    flow.instance_variable_get('@executor').shutdown
    flow.instance_variable_get('@executor').wait_for_termination(5)
  end

  describe '#initialize' do
    it 'creates an adapter' do
      expect(described_class.new(nil).adapter).to be_a Rackstash::Adapter::Null
    end

    it 'sets the default encoder from the adapter' do
      encoder = adapter.default_encoder

      expect(adapter).to receive(:default_encoder).and_return(encoder)
      expect(flow.encoder).to equal encoder
    end

    it 'allows to set a custom encoder' do
      encoder = Rackstash::Encoder::Raw.new
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

  describe '#auto_flush' do
    it 'defaults to false' do
      expect(flow.auto_flush).to eql false
    end

    it 'sets a boolean value' do
      flow.auto_flush(true)
      expect(flow.auto_flush).to eql true
      expect(flow.auto_flush?).to eql true

      flow.auto_flush(false)
      expect(flow.auto_flush).to eql false
      expect(flow.auto_flush?).to eql false

      flow.auto_flush('something')
      expect(flow.auto_flush).to eql true
      expect(flow.auto_flush?).to eql true
    end

    it 'ignores a nil argument' do
      flow.auto_flush(true)
      expect(flow.auto_flush).to eql true

      flow.auto_flush(nil)
      expect(flow.auto_flush?).to eql true
    end
  end

  describe '#auto_flush=' do
    it 'sets a boolean value' do
      flow.auto_flush = true
      expect(flow.auto_flush?).to eql true

      flow.auto_flush = false
      expect(flow.auto_flush?).to eql false

      flow.auto_flush = 'something'
      expect(flow.auto_flush?).to eql true

      flow.auto_flush = nil
      expect(flow.auto_flush?).to eql false
    end
  end

  describe '#auto_flush!' do
    it 'enables the auto_flush property' do
      flow.auto_flush!
      expect(flow.auto_flush?).to eql true
    end
  end

  describe '#close' do
    it 'calls adapter#close' do
      expect(adapter).to receive(:close)
      flow.close
    end

    context 'when asynchronous' do
      before do
        flow_args[:synchronous] = false
      end

      it 'logs errors thrown by the adapter' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)
        expect(error_flow).to receive(:write)
          .with(
            'error' => 'RuntimeError',
            'error_message' => 'ERROR',
            'error_trace' => instance_of(String),
            'tags' => [],
            'message' => [instance_of(Rackstash::Message)],
            '@timestamp' => instance_of(Time)
          )
        expect(adapter).to receive(:close).and_raise('ERROR')
        expect { flow.close }.not_to raise_error
      end

      it 'ignores errors thrown by the error_flow' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(adapter).to receive(:close).and_raise('ERROR')
        expect(error_flow).to receive(:write).and_raise('DOUBLE ERROR')

        expect { flow.close }.not_to raise_error
      end
    end

    context 'when synchronous' do
      before do
        flow_args[:synchronous] = true
      end

      it 'logs and re-raises errors thrown by the adapter' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(error_flow).to receive(:write)
          .with(
            'error' => 'RuntimeError',
            'error_message' => 'ERROR',
            'error_trace' => instance_of(String),
            'tags' => [],
            'message' => [instance_of(Rackstash::Message)],
            '@timestamp' => instance_of(Time)
          )
        expect(adapter).to receive(:close).and_raise('ERROR')
        expect { flow.close }.to raise_error RuntimeError, 'ERROR'
      end

      it 're-raises errors thrown by the error_flow' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(adapter).to receive(:close).and_raise('ERROR')
        expect(error_flow).to receive(:write).and_raise('DOUBLE ERROR')

        expect { flow.close }.to raise_error RuntimeError, 'DOUBLE ERROR'
      end
    end
  end

  describe '#encoder' do
    it 'returns the current encoder' do
      expect(flow.encoder).to respond_to(:encode)
      expect(flow.encoder(nil)).to respond_to(:encode)
    end

    it 'allows to set a new encoder' do
      encoder = Rackstash::Encoder::JSON.new
      expect(flow.encoder(encoder)).to equal encoder

      # The encoder is persisted and is returned afterwards
      expect(flow.encoder).to equal encoder
    end

    it 'allows to set an encoder spec' do
      expect { flow.encoder(:json) }.to change { flow.encoder }
        .from(instance_of(Rackstash::Encoder::Raw))
        .to(instance_of(Rackstash::Encoder::JSON))
    end

    it 'allows to set arguments to an encoder' do
      flow.encoder(:message, tagged: ['tags'])
      expect(flow.encoder).to be_instance_of(Rackstash::Encoder::Message)
      expect(flow.encoder.tagged).to eql ['tags']
    end
  end

  describe '#encoder=' do
    it 'sets a new encoder' do
      encoder = Rackstash::Encoder::JSON.new
      flow.encoder = encoder

      expect(flow.encoder).to equal encoder
    end

    it 'sets an encoder from a spec' do
      flow.encoder = :raw
      expect(flow.encoder).to be_a Rackstash::Encoder::Raw
    end

    it 'rejects invalid encoders' do
      # No registered encoder found
      expect { flow.encoder = :invalid }.to raise_error KeyError

      expect { flow.encoder = 23 }.to raise_error TypeError
      expect { flow.encoder = true }.to raise_error TypeError
      expect { flow.encoder = false }.to raise_error TypeError
      expect { flow.encoder = -> {} }.to raise_error TypeError
    end
  end

  describe '#error_flow' do
    it 'returns the global error_flow by default' do
      expect(Rackstash).to receive(:error_flow).twice.and_call_original

      expect(flow.error_flow).to be_instance_of described_class
      expect(flow.error_flow(nil)).to be_instance_of described_class
    end

    it 'can set a custom error_flow' do
      error_flow = described_class.new(adapter)
      expect(flow.error_flow(error_flow)).to equal error_flow

      # The error_flow is persisted and is returned afterwards
      expect(flow.error_flow).to equal error_flow
    end
  end

  describe '#error_flow=' do
    it 'creates a flow object when setting a value' do
      # load the flow helper so that the receive test below counts correctly
      flow

      expect(described_class).to receive(:new).with(adapter).and_call_original
      flow.error_flow = adapter

      expect(flow.error_flow).to be_instance_of described_class
      expect(flow.error_flow.adapter).to equal adapter
    end

    it 'resets the error_flow when setting nil' do
      flow.error_flow = flow
      expect(flow.error_flow).to equal flow
      expect(flow.error_flow).not_to equal Rackstash.error_flow

      flow.error_flow = nil
      expect(flow.error_flow).to equal Rackstash.error_flow
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

  describe '#synchronous?' do
    it 'defaults to false' do
      expect(flow.synchronous?).to eql false
    end

    it 'can set to true or false' do
      expect(described_class.new(adapter, synchronous: true).synchronous?).to eql true
      expect(described_class.new(adapter, synchronous: false).synchronous?).to eql false


      expect(described_class.new(adapter, synchronous: 'true').synchronous?).to eql true
      expect(described_class.new(adapter, synchronous: 42).synchronous?).to eql true
      expect(described_class.new(adapter, synchronous: nil).synchronous?).to eql false
    end
  end

  describe '#reopen' do
    it 'calls adapter#reopen' do
      expect(adapter).to receive(:reopen)
      flow.reopen
    end

    context 'when asynchronous' do
      before do
        flow_args[:synchronous] = false
      end

      it 'logs errors thrown by the adapter' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)
        expect(error_flow).to receive(:write)
          .with(
            'error' => 'RuntimeError',
            'error_message' => 'ERROR',
            'error_trace' => instance_of(String),
            'tags' => [],
            'message' => [instance_of(Rackstash::Message)],
            '@timestamp' => instance_of(Time)
          )
        expect(adapter).to receive(:reopen).and_raise('ERROR')
        expect { flow.reopen }.not_to raise_error
      end

      it 'ignores errors thrown by the error_flow' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(adapter).to receive(:reopen).and_raise('ERROR')
        expect(error_flow).to receive(:write).and_raise('DOUBLE ERROR')

        expect { flow.reopen }.not_to raise_error
      end
    end

    context 'when synchronous' do
      before do
        flow_args[:synchronous] = true
      end

      it 'logs and re-raises errors thrown by the adapter' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(error_flow).to receive(:write)
          .with(
            'error' => 'RuntimeError',
            'error_message' => 'ERROR',
            'error_trace' => instance_of(String),
            'tags' => [],
            'message' => [instance_of(Rackstash::Message)],
            '@timestamp' => instance_of(Time)
          )
        expect(adapter).to receive(:reopen).and_raise('ERROR')
        expect { flow.reopen }.to raise_error RuntimeError, 'ERROR'
      end

      it 're-raises errors thrown by the error_flow' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(adapter).to receive(:reopen).and_raise('ERROR')
        expect(error_flow).to receive(:write).and_raise('DOUBLE ERROR')

        expect { flow.reopen }.to raise_error RuntimeError, 'DOUBLE ERROR'
      end
    end
  end

  describe '#write!' do
  end

  describe '#write' do
    it 'calls write on the filter_chain' do
      expect(flow.filter_chain).to receive(:call)
      flow.write(event)
    end

    it 'aborts if the filter_chain returns false' do
      allow(flow.filter_chain).to receive(:call).and_return(false)

      expect(flow.encoder).not_to receive(:encode)
      expect(flow.adapter).not_to receive(:write)

      flow.write(event)
    end

    it 'writes the encoded event to the adapter' do
      expect(flow.encoder).to receive(:encode).and_return 'encoded'
      expect(flow.adapter).to receive(:write).with('encoded').and_call_original

      flow.write(event)
    end

    context 'when asynchronous' do
      before do
        flow_args[:synchronous] = false
      end

      it 'logs errors thrown by the adapter' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)
        expect(error_flow).to receive(:write)
          .with(
            'error' => 'RuntimeError',
            'error_message' => 'ERROR',
            'error_trace' => instance_of(String),
            'tags' => [],
            'message' => [instance_of(Rackstash::Message)],
            '@timestamp' => instance_of(Time)
          )
        expect(adapter).to receive(:write).and_raise('ERROR')
        expect { flow.write(event) }.not_to raise_error
      end

      it 'ignores errors thrown by the error_flow' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(adapter).to receive(:write).and_raise('ERROR')
        expect(error_flow).to receive(:write).and_raise('DOUBLE ERROR')

        expect { flow.write(event) }.not_to raise_error
      end
    end

    context 'when synchronous' do
      before do
        flow_args[:synchronous] = true
      end

      it 'logs and re-raises errors thrown by the adapter' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(error_flow).to receive(:write)
          .with(
            'error' => 'RuntimeError',
            'error_message' => 'ERROR',
            'error_trace' => instance_of(String),
            'tags' => [],
            'message' => [instance_of(Rackstash::Message)],
            '@timestamp' => instance_of(Time)
          )
        expect(adapter).to receive(:write).and_raise('ERROR')

        # flow.write(event)
        expect { flow.write(event) }.to raise_error RuntimeError, 'ERROR'
      end

      it 're-raises errors thrown by the error_flow' do
        error_flow = instance_double(described_class)
        allow(flow).to receive(:error_flow).and_return(error_flow)

        expect(adapter).to receive(:write).and_raise('ERROR')
        expect(error_flow).to receive(:write).and_raise('DOUBLE ERROR')

        expect { flow.write(event) }.to raise_error RuntimeError, 'DOUBLE ERROR'
      end
    end
  end
end
