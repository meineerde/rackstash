# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'securerandom'

require 'rackstash/filter'

describe Rackstash::Filter do
  let(:registry) { Rackstash::ClassRegistry.new('filter') }

  let(:filter_class) {
    Class.new do
      def call(_event)
        'filtered'
      end
    end
  }
  let(:filter_name) { :"filter_class_#{SecureRandom.hex(6)}" }

  describe '.build' do
    before do
      allow(described_class).to receive(:registry).and_return(registry)
      described_class.register(filter_class, filter_name)
    end

    it 'builds a filter from a class' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_class, *args)
    end

    it 'builds a filter from a Symbol' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_name.to_sym, *args)
    end

    it 'builds a filter from a String' do
      args = ['arg1', foo: 'bar']
      expect(filter_class).to receive(:new).with(*args)

      described_class.build(filter_name.to_s, *args)
    end

    it 'returns an existing filter' do
      filter = -> {}

      expect(described_class.build(filter)).to equal filter
      expect(described_class.build(filter, :ignored, 42)).to equal filter
    end

    context 'with conditionals' do
      let(:event) { Object.new }

      it 'applies the only_if conditional for new filters' do
        only_if = -> {}
        filter = described_class.build(filter_name, only_if: only_if)

        expect(only_if).to receive(:call).and_return false
        expect { filter.call({}) }.not_to raise_error
      end

      it 'applies the not_if conditional for new filters' do
        not_if = -> {}
        filter = described_class.build(filter_name, not_if: not_if)

        expect(not_if).to receive(:call).and_return true
        expect(filter.call(event)).to equal event
      end

      it 'applies both conditionals for new filters' do
        only_if = -> {}
        not_if = -> {}

        filter = described_class.build(filter_name, only_if: only_if, not_if: not_if)

        expect(only_if).to receive(:call).and_return true
        expect(not_if).to receive(:call).and_return false
        expect(filter.call(event)).to eql 'filtered'
      end

      it 'keeps the class hierarchy unchanged' do
        filter = described_class.build(filter_name, only_if: ->(_event) { false })

        expect(filter).to be_instance_of(filter_class)
      end

      it 'ignores the conditional for existing filters' do
        filter = filter_class.new
        only_if = -> {}

        expect(described_class.build(filter, only_if: only_if))
          .to equal filter

        expect(only_if).not_to receive(:call)
        expect(described_class.build(filter, only_if: only_if).call(event))
          .to eql 'filtered'
      end

      it 'passes keyword arguments to the initializer' do
        filter_class.class_eval do
          def initialize(mandatory:)
            @mandatory = mandatory
          end

          attr_reader :mandatory
        end

        filter = described_class.build(filter_name, only_if: -> {}, mandatory: 'foo')
        expect(filter.mandatory).to eql 'foo'
      end
    end

    context 'without conditionals' do
      it 'passes keyword arguments to the initializer' do
        filter_class.class_eval do
          def initialize(mandatory:)
            @mandatory = mandatory
          end

          attr_reader :mandatory
        end

        filter = described_class.build(filter_name, mandatory: 'foo')
        expect(filter.mandatory).to eql 'foo'
      end
    end

    it 'raises a TypeError with invalid spec types' do
      expect { described_class.build(123) }
        .to raise_error(TypeError, '123 can not be used to describe filters')
      expect { described_class.build(nil) }
        .to raise_error(TypeError, 'nil can not be used to describe filters')
      expect { described_class.build(true) }
        .to raise_error(TypeError, 'true can not be used to describe filters')
    end

    it 'raises a KeyError for undefined filters' do
      expect { described_class.build('MissingFilter') }
        .to raise_error(KeyError, 'No filter was registered for "MissingFilter"')
      expect { described_class.build(:missing_filter) }
        .to raise_error(KeyError, 'No filter was registered for :missing_filter')
    end
  end

  describe '.registry' do
    it 'returns the filter registry' do
      expect(described_class.registry).to be_instance_of Rackstash::ClassRegistry
      expect(described_class.registry.object_type).to eql 'filter'
    end
  end

  describe '.register' do
    let(:filter_class) {
      Class.new do
        def call
        end
      end
    }

    it 'registers a filter class' do
      expect(described_class.registry).to receive(:[]=).with(:foo, filter_class).ordered
      expect(described_class.registry).to receive(:[]=).with(:bar, filter_class).ordered

      described_class.register(filter_class, :foo, :bar)
    end

    it 'rejects invalid classes' do
      expect(described_class.registry).not_to receive(:[]=)

      expect { described_class.register(:not_a_class, :foo) }.to raise_error TypeError
      expect { described_class.register(Class.new, :foo) }.to raise_error TypeError
    end

    it 'rejects invalid names' do
      expect { described_class.register(filter_class, 123) }.to raise_error TypeError
    end
  end
end
