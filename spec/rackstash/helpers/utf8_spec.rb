# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/helpers/utf8'

describe Rackstash::Helpers::UTF8 do
  it 'only defines protected methods' do
    expect(described_class.public_instance_methods(false)).to be_empty
  end

  describe '#utf8_encode' do
    def utf8_encode(*args)
      Object.new.extend(described_class).send(:utf8_encode, *args)
    end

    it 'transforms encoding to UTF-8' do
      utf8_str = 'Dönerstraße'
      latin_str = utf8_str.encode(Encoding::ISO8859_9)
      expect(latin_str.encoding).to eql Encoding::ISO8859_9

      expect(utf8_encode(latin_str)).to eql utf8_str
      expect(utf8_encode(latin_str).encoding).to eql Encoding::UTF_8
      expect(utf8_encode(latin_str)).to be_frozen
    end

    it 'replaces invalid characters in correctly encoded strings' do
      binary = Digest::SHA256.digest('string')

      expect(utf8_encode(binary)).to include '�'
      expect(utf8_encode(binary).encoding).to eql Encoding::UTF_8
      expect(utf8_encode(binary)).to be_frozen
    end

    it 'replaces invalid characters in incorrectly encoded strings' do
      strange = Digest::SHA256.digest('string').force_encoding(Encoding::UTF_8)

      expect(utf8_encode(strange)).to include '�'
      expect(utf8_encode(strange).encoding).to eql Encoding::UTF_8
      expect(utf8_encode(strange)).to be_frozen
    end

    it 'dups and freezes valid strings' do
      valid = String.new('Dönerstraße')
      expect(valid).to_not be_frozen

      expect(utf8_encode(valid)).to eql(valid)
      # Not object-equal since the string was dup'ed
      expect(utf8_encode(valid)).not_to equal valid
      expect(utf8_encode(valid)).to be_frozen
    end

    it 'does not alter valid frozen strings' do
      valid = 'Dönerstraße'.freeze
      expect(utf8_encode(valid)).to equal(valid)
    end
  end
end
