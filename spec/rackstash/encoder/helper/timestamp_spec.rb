# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/helper/timestamp'

describe Rackstash::Encoder::Helper::Timestamp do
  let(:helper) {
    helper = Object.new.extend(described_class)
    described_class.private_instance_methods(false).each do |method|
      helper.define_singleton_method(method) do |*args|
        super(*args)
      end
    end
    helper
  }
  let(:event) { {} }

  describe '#normalize_timestamp' do
    it 'formats a Time object' do
      event['@timestamp'] = Time.parse('2016-10-17 13:37:00 +03:00')
      expect(helper.normalize_timestamp(event).fetch('@timestamp'))
        .to eql '2016-10-17T10:37:00.000000Z'
    end

    it 'formats a DateTime object' do
      event['@timestamp'] = DateTime.parse('2016-10-17 13:37:00 +03:00')
      expect(helper.normalize_timestamp(event).fetch('@timestamp'))
        .to eql '2016-10-17T10:37:00.000000Z'
    end

    it 'ignores an unset value' do
      expect(helper.normalize_timestamp(event)).not_to have_key '@timestamp'
    end

    it 'ignores unknown values' do
      event['@timestamp'] = 'string'
      expect(helper.normalize_timestamp(event).fetch('@timestamp')).to eql 'string'

      event['@timestamp'] = nil
      expect(helper.normalize_timestamp(event).fetch('@timestamp')).to eql nil

      event['@timestamp'] = 42
      expect(helper.normalize_timestamp(event).fetch('@timestamp')).to eql 42
    end

    it 'uses the given field name' do
      event['@timestamp'] = Time.parse('2016-10-17 13:37:00 +03:00')
      event['custom'] = Time.parse('2016-10-17 20:42:00 +07:00')

      expect(helper.normalize_timestamp(event, field: 'custom')).to match(
        '@timestamp' => instance_of(Time),
        'custom' => '2016-10-17T13:42:00.000000Z'
      )
    end
  end
end
