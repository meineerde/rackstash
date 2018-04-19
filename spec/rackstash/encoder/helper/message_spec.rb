# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/encoder/helper/message'

RSpec.describe Rackstash::Encoder::Helper::Message do
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
      event['message'] = ["a\n", "b\n", 42]

      expect(helper.normalize_message(event)).to eql 'message' => "a\nb\n42"
    end

    it 'does not set a missing message' do
      expect(helper.normalize_message(event)).to eql Hash.new

      event['message'] = nil
      expect(helper.normalize_message(event)).to eql 'message' => nil
    end

    it 'enforces to_s on other messages' do
      event['message'] = :foo
      expect(helper.normalize_message(event)).to eql 'message' => 'foo'
    end
  end
end
