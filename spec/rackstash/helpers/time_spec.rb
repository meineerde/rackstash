# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/helpers/time'

describe Rackstash::Helpers::Time do
  it 'only defines protected methods' do
    expect(described_class.public_instance_methods(false)).to be_empty
  end

  describe '#clock_time' do
    def clock_time(*args)
      Object.new.extend(described_class).send(:clock_time, *args)
    end

    it 'returns the numeric timestamp' do
      expect(clock_time).to be_a Float
    end

    it 'is monotinically increasing' do
      expect(clock_time).to be < clock_time
    end
  end
end
