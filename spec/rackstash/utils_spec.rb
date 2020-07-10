# frozen_string_literal: true
#
# Copyright 2017 - 2020 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/utils'
require 'openssl'

RSpec.describe Rackstash::Utils do
  describe '#utf8' do
    it 'transforms encoding to UTF-8' do
      utf8_str = 'Dönerstraße'
      latin_str = utf8_str.encode(Encoding::ISO8859_9)
      expect(latin_str.encoding).to eql Encoding::ISO8859_9

      expect(described_class.utf8(latin_str)).to eql utf8_str
      expect(described_class.utf8(latin_str).encoding).to eql Encoding::UTF_8
      expect(described_class.utf8(latin_str)).to be_frozen
    end

    it 'replaces invalid characters in correctly encoded strings' do
      binary = OpenSSL::Digest::SHA256.digest('string')

      expect(described_class.utf8(binary)).to include '�'
      expect(described_class.utf8(binary).encoding).to eql Encoding::UTF_8
      expect(described_class.utf8(binary)).to be_frozen
    end

    it 'replaces invalid characters in incorrectly encoded strings' do
      strange = OpenSSL::Digest::SHA256.digest('string').force_encoding(Encoding::UTF_8)

      expect(described_class.utf8(strange)).to include '�'
      expect(described_class.utf8(strange).encoding).to eql Encoding::UTF_8
      expect(described_class.utf8(strange)).to be_frozen
    end

    it 'dups and freezes valid strings' do
      valid = String.new('Dönerstraße')
      expect(valid).to_not be_frozen

      expect(described_class.utf8(valid)).to eql(valid)
      # Not object-equal since the string was dup'ed
      expect(described_class.utf8(valid)).not_to equal valid
      expect(described_class.utf8(valid)).to be_frozen
    end

    it 'does not alter valid frozen strings' do
      valid = 'Dönerstraße'.freeze
      expect(described_class.utf8(valid)).to equal(valid)
    end
  end

  describe '#clock_time' do
    it 'returns the numeric timestamp' do
      expect(described_class.clock_time).to be_a Float
    end

    it 'is monotonically increasing' do
      expect(described_class.clock_time).to be < described_class.clock_time
    end

    context 'without a monotonic clock' do
      around do |example|
        clock_monotic = ::Process.send(:remove_const, :CLOCK_MONOTONIC)
        verbose, $VERBOSE = $VERBOSE, false
        load File.expand_path('../../lib/rackstash/utils.rb', __dir__)
        $VERBOSE = verbose

        example.run

        ::Process::CLOCK_MONOTONIC = clock_monotic
        verbose, $VERBOSE = $VERBOSE, false
        load File.expand_path('../../lib/rackstash/utils.rb', __dir__)
        $VERBOSE = verbose
      end

      if Gem.win_platform?
        it 'fetches the GetTickCount64 function' do
          expect(described_class::GetTickCount64).to be_a Fiddle::Function
        end

        it 'returns a float' do
          expect(described_class::GetTickCount64).to receive(:call).and_call_original
          expect(described_class.clock_time).to be_a(Float)
        end
      else
        it 'returns a float' do
          expect(::Time).to receive(:now).and_call_original
          expect(described_class.clock_time).to be_a Float
        end
      end
    end
  end
end
