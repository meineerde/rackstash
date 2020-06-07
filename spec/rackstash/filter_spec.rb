# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'securerandom'

require 'rackstash/filter'

RSpec.describe Rackstash::Filter do
  let(:filter_class) {
    Class.new do
      attr_reader :args, :kwargs

      def initialize(*args, **kwargs)
        @args = args
        @kwargs = kwargs

        @called = false
        @called_with_if = false
        @called_with_unless = false
      end

      def if(event)
        @called_with_if = true
        @kwargs[:if]
      end

      def unless(event)
        @called_with_unless = true
        @kwargs[:unless]
      end

      def call(_event)
        @called = true
        'filtered'
      end

      %i[called called_with_if called_with_unless].each do |m|
        define_method(:"#{m}?") { instance_variable_get("@#{m}") }
      end
    end
  }
  let(:filter_name) { :"filter_class_#{SecureRandom.hex(6)}" }

  around(:each) do |example|
    original_filters = described_class.registry.to_h
    described_class.registry.clear
    example.run
    original_filters.each do |name, registered_clas|
      described_class.registry[name] = registered_clas
    end
  end

  before(:each) do
    described_class.register(filter_class, filter_name)
  end

  describe '.build' do
    it 'builds a filter from a class' do
      args = ['arg1']
      kwargs = { foo: 'bar' }

      filter = described_class.build(filter_class, *args, **kwargs)
      expect(filter).to be_a filter_class
      expect(filter.args).to eq args
      expect(filter.kwargs).to eq kwargs
    end

    it 'builds a filter from a Symbol' do
      args = ['arg1']
      kwargs = { foo: 'bar' }

      filter = described_class.build(filter_name.to_sym, *args, **kwargs)
      expect(filter).to be_a filter_class
      expect(filter.args).to eq args
      expect(filter.kwargs).to eq kwargs
    end

    it 'builds a filter from a String' do
      args = ['arg1']
      kwargs = { foo: 'bar' }

      filter = described_class.build(filter_name.to_s, *args, **kwargs)
      expect(filter).to be_a filter_class
      expect(filter.args).to eq args
      expect(filter.kwargs).to eq kwargs
    end

    it 'returns an existing filter' do
      filter = -> {}

      expect(described_class.build(filter)).to equal filter
      expect(described_class.build(filter, :ignored, 42)).to equal filter
    end

    context 'with conditionals' do
      let(:event) { Object.new }

      it 'applies the only_if conditional for new filters' do
        only_if = ->(_event) { false }
        filter = described_class.build(filter_name, only_if: only_if)
        expect(filter.call(event)).to equal event
        expect(filter).not_to be_called

        only_if = ->(_event) { true }
        filter = described_class.build(filter_name, only_if: only_if)
        expect(filter.call(event)).to eql 'filtered'
        expect(filter).to be_called
      end

      it 'applies the only_if filter conditional for new filters' do
        filter = described_class.build(filter_name, only_if: :if, if: false)
        filter.call(event)
        expect(filter).to be_called_with_if
        expect(filter).not_to be_called

        filter = described_class.build(filter_name, only_if: :if, if: true)
        expect(filter.call(event)).to eql 'filtered'
        expect(filter).to be_called
        expect(filter).to be_called_with_if
      end

      it 'applies the not_if conditional for new filters' do
        not_if = ->(_event) { true }
        filter = described_class.build(filter_name, not_if: not_if)
        expect(filter.call(event)).to equal event
        expect(filter).not_to be_called

        not_if = ->(_event) { false }
        filter = described_class.build(filter_name, not_if: not_if)
        expect(filter.call(event)).to eql 'filtered'
        expect(filter).to be_called
      end

      it 'applies the not_if filter conditional for new filters' do
        filter = described_class.build(filter_name, not_if: :unless, unless: true)
        expect(filter.call(event)).to equal event
        expect(filter).not_to be_called
        expect(filter).to be_called_with_unless

        filter = described_class.build(filter_name, not_if: :unless, unless: false)
        expect(filter.call(event)).to eql 'filtered'
        expect(filter).to be_called
        expect(filter).to be_called_with_unless
      end

      it 'applies both conditionals for new filters' do
        only_if = ->(_event) { true }
        not_if = ->(_event) { false }
        filter = described_class.build(filter_name, only_if: only_if, not_if: not_if)

        expect(filter.call(event)).to eql 'filtered'
        expect(filter).to be_called
      end

      it 'keeps the class hierarchy unchanged' do
        filter = described_class.build(filter_name, only_if: ->(_event) { false })

        expect(filter).to be_instance_of(filter_class)
      end

      it 'ignores the conditional for existing filters' do
        filter = filter_class.new
        only_if = ->(_event) {}

        expect(described_class.build(filter, only_if: only_if))
          .to equal filter

        expect(only_if).not_to receive(:call)
        expect(described_class.build(filter, only_if: only_if).call(event))
          .to eql 'filtered'
      end

      it 'passes keyword arguments to the initializer' do
        filter = described_class.build(filter_name, 'foo', only_if: -> {}, argument: 'bar')
        expect(filter.args).to eq ['foo']
        expect(filter.kwargs).to eq argument: 'bar'
      end

      it 'expects callable objects' do
        object = false

        expect { described_class.build(filter_name, only_if: object) }
          .to raise_error(TypeError, 'Invalid only_if filter')
        expect { described_class.build(filter_name, not_if: object) }
          .to raise_error(TypeError, 'Invalid not_if filter')
      end
    end

    context 'without conditionals' do
      it 'passes arguments to the initializer' do
        filter = described_class.build(filter_name, 'foo', argument: 'bar')

        expect(filter.args).to eq ['foo']
        expect(filter.kwargs).to eq argument: 'bar'
      end
    end

    it 'raises a TypeError with invalid spec types' do
      expect { described_class.build(123) }
        .to raise_error(TypeError, '123 can not be used to describe filter classes')
      expect { described_class.build(nil) }
        .to raise_error(TypeError, 'nil can not be used to describe filter classes')
      expect { described_class.build(true) }
        .to raise_error(TypeError, 'true can not be used to describe filter classes')
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
    it 'registers a filter class' do
      described_class.register(filter_class, :foo, :bar)
      expect(described_class.registry.fetch(:foo)).to equal filter_class
      expect(described_class.registry.fetch(:bar)).to equal filter_class
    end

    it 'rejects invalid classes' do
      expect { described_class.register(:not_a_class, :foo) }.to raise_error TypeError
      expect { described_class.register(Class.new, :foo) }.to raise_error TypeError

      expect(described_class.registry[:foo]).to be_nil
    end
  end
end
