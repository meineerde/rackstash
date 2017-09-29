# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoders/helpers/message'

describe Rackstash::Encoders::Helpers::Message do
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

  describe '#normalize_message' do
    it 'concatenates the message array' do
      event['message'] = ["a\n", "b\n"]

      expect(helper.normalize_message(event)).to eql 'message' => "a\nb\n"
    end

    it 'sets message to an empty string if not present' do
      event['message'] = nil
      expect(helper.normalize_message(event)).to eql 'message' => ''
    end

    it 'enforces to_s on other messages' do
      foo = String.new('foo')
      event['message'] = foo

      expect(foo).to receive(:to_s).and_call_original
      expect(helper.normalize_message(event)).to eql 'message' => 'foo'
    end
  end
end
