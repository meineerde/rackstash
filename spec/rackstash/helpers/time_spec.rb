# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/helpers/time'

RSpec.describe Rackstash::Helpers::Time do
  it 'only defines protected methods' do
    expect(described_class.public_instance_methods(false)).to be_empty
  end

  describe '#clock_time' do
    def clock_time(*args)
      Object.new.extend(described_class).send(:clock_time, *args)
    end

    it 'returns the numeric timestamp' do
      expect(::Process::CLOCK_MONOTONIC).to_not be_nil
      expect(::Time).not_to receive(:now)
      expect(clock_time).to be_a Float
    end

    it 'is monotinically increasing' do
      expect(clock_time).to be < clock_time
    end

    context 'without a monotonic clock' do
      around do |example|
        clock_monotic = ::Process.send(:remove_const, :CLOCK_MONOTONIC)
        verbose, $VERBOSE = $VERBOSE, false
        load File.expand_path('../../../lib/rackstash/helpers/time.rb', __dir__)
        $VERBOSE = verbose

        example.run

        ::Process::CLOCK_MONOTONIC = clock_monotic
        verbose, $VERBOSE = $VERBOSE, false
        load File.expand_path('../../../lib/rackstash/helpers/time.rb', __dir__)
        $VERBOSE = verbose
      end

      it 'returns a float' do
        expect(::Time).to receive(:now).and_call_original
        expect(clock_time).to be_a Float
      end
    end
  end
end
