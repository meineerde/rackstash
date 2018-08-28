# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter/drop'

RSpec.describe Rackstash::Filter::Drop do
  let(:event) {
    {what: :ever}
  }

  describe '#initialize' do
    it 'accepts a percentage' do
      filter = described_class.new(percent: 23)
      expect(filter.percent).to eql 23
    end

    it 'defaults to 100%' do
      expect(described_class.new.percent).to eql 100
    end

    it 'only accepts valid percentages' do
      expect { described_class.new(percent: -1) }.to raise_error ArgumentError
      expect { described_class.new(percent: 101) }.to raise_error ArgumentError
      expect { described_class.new(percent: 'value') }.to raise_error ArgumentError
      expect { described_class.new(percent: :value) }.to raise_error TypeError
      expect { described_class.new(percent: false) }.to raise_error TypeError
    end

  end

  describe '#call' do
    it 'always returns the event with percent: 0' do
      drop_all = described_class.new(percent: 0)

      expect(1_000.times.count { drop_all.call(event) == event }).to eql 1_000
    end

    it 'drops about half of the events with percent: 50' do
      drop_half = described_class.new(percent: 50)
      expect(drop_half).to receive(:random_percentage)
        .and_return(*[0, 99] * 500)

      expect(1_000.times.count { drop_half.call(event) == event })
        .to eql 500
    end

    it 'drops 99% of the events with percent: 99' do
      drop_most = described_class.new(percent: 99)
      expect(drop_most).to receive(:random_percentage)
        .and_return(*(0..99).to_a.shuffle * 10)

      expect(1_000.times.count { drop_most.call(event) == event })
        .to eql 10
    end

    it 'always returns false with percent: 100' do
      drop_all = described_class.new(percent: 100)

      expect(1_000.times.count { drop_all.call(event) == event }).to eql 0
    end
  end
end
