# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/helper/fields_map'

RSpec.describe Rackstash::Encoder::Helper::FieldsMap do
  let(:helper) {
    helper = Object.new.extend(described_class)
    described_class.private_instance_methods(false).each do |method|
      helper.define_singleton_method(method) do |*args, &block|
        super(*args, &block)
      end
    end
    helper
  }
  let(:event) {
    {
    'foo' => 'hello',
    'bar' => 'world'
    }
  }

  describe '#extract_field' do
    context 'with defaults' do
      let(:defaults) { { default: 'foo' } }

      it 'uses default fields' do
        helper.set_fields_mapping({ something: 'beep' }, defaults)
        expect(helper.extract_field(:default, event)).to eql 'hello'
      end

      it 'can overwrite default fields' do
        helper.set_fields_mapping({ default: 'bar' }, defaults)
        expect(helper.extract_field(:default, event)).to eql 'world'
      end
    end

    it 'returns the field value if it exists' do
      helper.set_fields_mapping({}, { field: 'foo' })
      expect(helper.extract_field(:field, event)).to eql 'hello'
    end

    it 'returns nil if the field does not exist' do
      helper.set_fields_mapping({}, { field: 'invalid' })
      expect(helper.extract_field(:field, event)).to eql nil
    end

    it 'returns the result of the given block if the field does not exist' do
      helper.set_fields_mapping({}, { field: 'invalid' })
      expect(helper.extract_field(:field, event) { 123 }).to eql 123
    end

    it 'yield the resolved field name' do
      helper.set_fields_mapping({}, { field: 'field' })
      expect { |b| helper.extract_field(:field, event, &b) }.to yield_with_args('field')
    end
  end
end
