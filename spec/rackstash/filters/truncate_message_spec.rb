# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filters/truncate_message'

describe Rackstash::Filters::TruncateMessage do
  let(:max_size) { 30 }
  let(:args) { { selectors: [], cut: :bottom } }
  let(:filter) { described_class.new(max_size, **args) }

  let(:messages) { ['some long message', 'sweet middle text', 'final message'] }
  let(:event) { { 'message' => messages } }

  def callable(&block)
    Class.new do
      define_method(:call) do |message|
        block.call(message)
      end
    end.new
  end

  describe '#initialize' do
    it 'verifies that a valid cut value is given' do
      expect { described_class.new(42, cut: 'foo') }.to raise_error(ArgumentError)
      expect { described_class.new(42, cut: :foo) }.to raise_error(ArgumentError)
      expect { described_class.new(42, cut: false) }.to raise_error(ArgumentError)
      expect { described_class.new(42, cut: nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#call' do
    context 'with selectors' do
      it 'calls all selectors' do
        selector_1 = ->(message) { true }
        selector_2 = callable { true }
        args[:selectors] = [selector_1, selector_2]

        # selector_1 is a proc and is thus passed directly as a block to select!
        expect(selector_2).to receive(:call).exactly(messages.count)

        filter.call(event)
      end

      it 'stops on goal' do
        selector_1 = callable { false }
        selector_2 = callable { true }
        args[:selectors] = [selector_1, selector_2]

        expect(selector_1).to receive(:call).exactly(3).times.and_call_original
        expect(selector_2).not_to receive(:call)

        filter.call(event)
        expect(messages).to be_empty
      end
    end

    context 'with cut: :top' do
      before(:each) do
        args[:cut] = :top
      end

      it 'removes the messages at the beginning' do
        filter.call(event)
        expect(messages).to eql ['sweet middle text', 'final message']
      end
    end

    context 'with cut: :middle' do
      before(:each) do
        args[:cut] = :middle
      end

      it 'removes the messages in the middle' do
        filter.call(event)
        expect(messages).to eql ['some long message', 'final message']
      end
    end

    context 'with cut: :bottom' do
      before(:each) do
        args[:cut] = :bottom
      end

      it 'removes the messages at the end' do
        filter.call(event)
        expect(messages).to eql ['some long message']
      end
    end
  end
end
