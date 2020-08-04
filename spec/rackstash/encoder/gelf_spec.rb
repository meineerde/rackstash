# frozen_string_literal: true
#
# Copyright 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/gelf'

RSpec.describe Rackstash::Encoder::GELF do
  let(:encoder_args) { {} }
  let(:encoder) { described_class.new(**encoder_args) }

  describe 'version field' do
    it 'adds a fixed version' do
      expect(encoder.encode({})).to include '"version":"1.1"'
    end
  end

  describe 'host field' do
    it 'adds the current host by default' do
      allow(Socket).to receive(:gethostname).and_return('foo')
      expect(encoder.encode({})).to include '"host":"foo"'
    end

    it 'uses the configured host field' do
      encoder_args[:fields] = { host: 'host_field' }

      expect(Socket).not_to receive(:gethostname)
      expect(encoder.encode('host_field' => 'foo')).to include '"host":"foo"'
      expect(encoder.encode('host_field' => 'foo')).not_to include 'host_field'
    end

    it 'adds the current host if the host field is missing' do
      encoder_args[:fields] = { host: 'host_field' }

      allow(Socket).to receive(:gethostname).and_return('localhorst.example.com')
      expect(encoder.encode({})).to include '"host":"localhorst.example.com"'
    end
  end

  describe 'timestamp field' do
    it 'formats the event timestamp' do
      event = { '@timestamp' => DateTime.new(2016, 10, 17, 16, 37, 0, '+03:00') }
      expect(encoder.encode(event)).to include '"timestamp":1476711420.0'
      expect(encoder.encode(event)).not_to include '@timestamp'
    end

    it 'formats a DateTime' do
      event = { '@timestamp' => DateTime.new(2016, 10, 17, 16, 37, 0, '+03:00') }
      expect(encoder.encode(event)).to include '"timestamp":1476711420.0'
    end

    it 'formats a Date' do
      event = { '@timestamp' => Date.new(2016, 10, 17) }
      expect(encoder.encode(event)).to include '"timestamp":1476662400.0'
    end

    it 'formats a String' do
      event = { '@timestamp' => '2016-10-17T16:37:00+03:00' }
      expect(encoder.encode(event)).to include '"timestamp":1476711420.0'
    end

    it 'formats an Integer' do
      event = { '@timestamp' => 1476711420 }
      expect(encoder.encode(event)).to include '"timestamp":1476711420.0'
    end


    it 'adds the current timestamp by default' do
      allow(Time).to receive(:now)
        .and_return Time.new(2017, 12, 17, 16, 37, 0, '+03:00')
      expect(encoder.encode({})).to include '"timestamp":1513517820.0'
    end
  end

  describe 'level field' do
    it 'uses the configured level field' do
      encoder_args[:fields] = { level: 'level_field' }

      messages = [instance_double('Rackstash::Message', severity: 3)]

      expect(encoder.encode('message' => messages, 'level_field' => 1))
        .to include '"level":1'
      expect(encoder.encode('message' => messages, 'level_field' => 1))
        .not_to include 'level_field'
    end

    it 'sets the level to UNKNOWN without any messages' do
      expect(encoder.encode({})).to include '"level":1'
    end

    it 'extracts the highest severity from the messages to get the level' do
      messages = [
        instance_double('Rackstash::Message', severity: 0), # DEBUG
        instance_double('Rackstash::Message', severity: 3), # ERROR
        instance_double('Rackstash::Message', severity: 1), # INFO
      ]

      expect(encoder.encode('message' => messages)).to include '"level":4'
    end

    it 'ignores invalid message severities' do
      messages = [
        instance_double('Rackstash::Message', severity: 123),
        instance_double('Rackstash::Message', severity: 5),
        'a string',
        32,
        nil
      ]

      expect(encoder.encode('message' => messages)).to include '"level":1'
      expect(encoder.encode('message' => nil)).to include '"level":1'
      expect(encoder.encode('message' => '')).to include '"level":1'
    end

    context 'with default_severity' do
      before do
        encoder_args[:default_severity] = 1
      end

      it 'uses the custom default level' do
        messages = [
          instance_double('Rackstash::Message', severity: 123),
          instance_double('Rackstash::Message', severity: 5),
          instance_double('Rackstash::Message', severity: -3)
        ]

        expect(encoder.encode('message' => messages)).to include '"level":6'
        expect(encoder.encode('message' => nil)).to include '"level":6'
        expect(encoder.encode('message' => '')).to include '"level":6'
        expect(encoder.encode('message' => [messages.last])).to include '"level":6'
        expect(encoder.encode({})).to include '"level":6'
      end

      it 'can set a higher level' do
        messages = [
          instance_double('Rackstash::Message', severity: 4)
        ]

        expect(encoder.encode('message' => messages)).to include '"level":3'
      end
    end
  end

  describe 'short_message field' do
    it 'adds the event message to the short_message field by default' do
      expect(encoder.encode('message' => ['Hello', 'World']))
        .to include '"short_message":"Hello\nWorld"'
    end

    it 'uses the configured short_message field' do
      encoder_args[:fields] = { short_message: 'gelf_message' }

      event = {
        'message' => ['Hello', 'World'],
        'gelf_message' => 'Hello GELF'
      }

      expect(encoder.encode(event))
        .to include('"short_message":"Hello GELF"')
        .and include('"_message":"Hello\nWorld"')
    end

    it 'sets an empty short_message if the configured field is missing' do
      encoder_args[:fields] = { short_message: 'gelf_message' }

      expect(encoder.encode({})).to include('"short_message":""')
    end
  end

  describe 'full_message field' do
    it 'does not include the field by default' do
      expect(encoder.encode({})).not_to include 'full_message'
    end

    it 'includes the field if configured and present' do
      encoder_args[:fields] = { full_message: 'full' }

      expect(encoder.encode('full' => 'GELF MESSAGE'))
        .to include '"full_message":"GELF MESSAGE"'
    end

    it 'does not include the field if configured and NOT present' do
      encoder_args[:fields] = { full_message: 'full' }

      expect(encoder.encode({})).not_to include 'full_message'
    end
  end

  describe 'additional fields' do
    it 'adds additional simple fields' do
      expect(encoder.encode(
        'str' => 'hello world',
        'int' => 123,
        'f' => 3.14,
        'date' => Date.new(2017, 3, 6),
        'time' => Time.new(2017, 2, 17, 16, 37, 0, '+03:00'),
        'datetime' => DateTime.new(2016, 10, 7, 16, 37, 0, '+03:00')
      ))
        .to include('"_str":"hello world"')
        .and include('"_int":123')
        .and include('"_f":3.14')
        .and include('"_date":"2017-03-06"')
        .and include('"_time":"2017-02-17T13:37:00.000000Z"')
        .and include('"_datetime":"2016-10-07T13:37:00.000000Z"')
    end

    it 'normalizes keys' do
      expect(encoder.encode('with spaces' => 'value', 'Motörhead' => "band"))
        .to include('"_with_spaces":"value"')
        .and include('"_Mot_rhead":"band"')
    end

    it "transforms the id key" do
      expect(encoder.encode('id' => 123, 'nested' => {'_id' => 42}))
        .to include('"__id":123')
        .and include('"_nested._id":42')
    end

    it 'adds nested hashes' do
      event = {
        'nested' => {
          'str' => 'beep',
          'int' => 123,
          'inner' => { 'foo' => 'bar' }
        }
      }

      expect(encoder.encode(event))
        .to include('"_nested.str":"beep"')
        .and include('"_nested.int":123')
        .and include('"_nested.inner.foo":"bar"')
    end

    it 'adds nested arrays' do
      expect(encoder.encode('array' => ['foo', 'bar', [123, 42]]))
        .to include('"_array.0":"foo"')
        .and include('"_array.1":"bar"')
        .and include('"_array.2.0":123')
        .and include('"_array.2.1":42')
    end
  end
end
