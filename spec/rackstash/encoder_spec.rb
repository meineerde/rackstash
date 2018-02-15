# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'securerandom'

require 'rackstash/encoder'

RSpec.describe Rackstash::Encoder do
  let(:registry) { Rackstash::ClassRegistry.new('encoder') }

  let(:encoder_class) {
    Class.new do
      def encode(event)
        'encoded'
      end
    end
  }
  let(:encoder_name) { :"encoder_class_#{SecureRandom.hex(6)}" }

  describe '.build' do
    before do
      allow(described_class).to receive(:registry).and_return(registry)
      described_class.register(encoder_class, encoder_name)
    end

    it 'builds an encoder from a class' do
      args = ['arg1', foo: 'bar']
      expect(encoder_class).to receive(:new).with(*args)

      described_class.build(encoder_class, *args)
    end

    it 'builds a encoder from a Symbol' do
      args = ['arg1', foo: 'bar']
      expect(encoder_class).to receive(:new).with(*args)

      described_class.build(encoder_name.to_sym, *args)
    end

    it 'builds a encoder from a String' do
      args = ['arg1', foo: 'bar']
      expect(encoder_class).to receive(:new).with(*args)

      described_class.build(encoder_name.to_s, *args)
    end

    it 'returns an existing encoder' do
      encoder = Class.new do
        def encode(event)
          'custom'
        end
      end.new

      expect(described_class.build(encoder)).to equal encoder
      expect(described_class.build(encoder, :ignored, 42)).to equal encoder
    end

    it 'raises a TypeError with invalid spec types' do
      expect { described_class.build(123) }
        .to raise_error(TypeError, '123 can not be used to describe encoder classes')
      expect { described_class.build(nil) }
        .to raise_error(TypeError, 'nil can not be used to describe encoder classes')
      expect { described_class.build(true) }
        .to raise_error(TypeError, 'true can not be used to describe encoder classes')
    end

    it 'raises a KeyError for undefined encoders' do
      expect { described_class.build('MissingEncoder') }
        .to raise_error(KeyError, 'No encoder was registered for "MissingEncoder"')
      expect { described_class.build(:missing_encoder) }
        .to raise_error(KeyError, 'No encoder was registered for :missing_encoder')
    end
  end

  describe '.registry' do
    it 'returns the encoder registry' do
      expect(described_class.registry).to be_instance_of Rackstash::ClassRegistry
      expect(described_class.registry.object_type).to eql 'encoder'
    end
  end

  describe '.register' do
    let(:encoder_class) {
      Class.new do
        def encode; end
      end
    }

    it 'registers an encoder class' do
      expect(described_class.registry).to receive(:[]=).with(:foo, encoder_class).ordered
      expect(described_class.registry).to receive(:[]=).with(:bar, encoder_class).ordered

      described_class.register(encoder_class, :foo, :bar)
    end

    it 'rejects invalid classes' do
      expect(described_class.registry).not_to receive(:[]=)

      expect { described_class.register(:not_a_class, :foo) }.to raise_error TypeError
      expect { described_class.register(Class.new, :foo) }.to raise_error TypeError
    end

    it 'rejects invalid names' do
      expect { described_class.register(encoder_class, 123) }.to raise_error TypeError
    end
  end
end
