# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/fields/abstract_collection'
require 'rackstash/fields/array'
require 'rackstash/fields/hash'

describe Rackstash::Fields::AbstractCollection do
  let(:collection) { Rackstash::Fields::AbstractCollection.new }

  def normalize(*args)
    collection.send(:normalize, *args)
  end

  describe '#to_json' do
    it 'returns the JSON version of as_json' do
      as_json = double('JSON value')
      expect(collection).to receive(:as_json).and_return(as_json)
      expect(as_json).to receive(:to_json)

      collection.to_json
    end
  end

  describe '#inspect' do
    it 'formats the object' do
      expect(collection).to receive(:as_json).and_return('beepboop')
      expect(collection.inspect).to(
        match %r{\A#<Rackstash::Fields::AbstractCollection:0x[a-f0-9]+ "beepboop">\z}
      )
    end
  end

  describe '#eql?' do
    it 'is equal with the same class with the same raw value' do
      expect(collection).to receive(:eql?).twice.and_call_original
      expect(collection).to receive(:==).twice.and_call_original

      other = Rackstash::Fields::AbstractCollection.new
      expect(collection).to eql other
      expect(collection).to eq other

      other.send(:raw=, 'different value')
      expect(collection).not_to eql other
      expect(collection).not_to eq other
    end

    it 'is not equal on different classes' do
      other = Struct.new(:raw).new
      expect(collection.send(:raw)).to eql other.raw

      expect(collection).to receive(:eql?).and_call_original
      expect(collection).not_to eql other

      expect(collection).to receive(:==).and_call_original
      expect(collection).not_to eq other
    end
  end

  describe '#clone' do
    it 'clones the raw value' do
      raw = 'hello'
      collection.send(:raw=, raw)
      expect(collection.send(:raw)).to equal raw

      expect(raw).to receive(:clone).and_call_original
      cloned = collection.clone

      expect(cloned).not_to equal collection
      expect(cloned.send(:raw)).to eql 'hello'
      expect(cloned.send(:raw)).not_to equal raw
    end
  end

  describe '#dup' do
    it 'dups the raw value' do
      raw = 'hello'
      collection.send(:raw=, raw)
      expect(collection.send(:raw)).to equal raw

      expect(raw).to receive(:dup).and_call_original
      duped = collection.dup

      expect(duped).not_to equal collection
      expect(duped.send(:raw)).to eql 'hello'
      expect(duped.send(:raw)).not_to equal raw
    end
  end

  describe '#hash' do
    it 'returns the same hash for the same raw content' do
      collection.send(:raw=, [123, 'foo'])

      collection2 = Rackstash::Fields::AbstractCollection.new
      collection2.send(:raw=, [123, 'foo'])

      expect(collection.send(:raw)).not_to equal collection2.send(:raw)
      expect(collection.hash).to eql collection2.hash
    end
  end

  describe '#raw' do
    it 'is a protected accessor' do
      expect { collection.raw = nil }.to raise_error NoMethodError
      expect { collection.raw }.to raise_error NoMethodError

      collection.send(:raw=, 'beep')
      expect(collection.send(:raw)).to eql 'beep'
    end
  end

  describe '#normalize' do
    describe 'with String' do
      it 'transforms encoding to UTF-8' do
        utf8_str = 'Dönerstraße'
        latin_str = utf8_str.encode(Encoding::ISO8859_9)
        expect(latin_str.encoding).to eql Encoding::ISO8859_9

        expect(normalize(latin_str)).to eql utf8_str
        expect(normalize(latin_str).encoding).to eql Encoding::UTF_8
        expect(normalize(latin_str)).to be_frozen
      end

      it 'replaces invalid characters in correctly encoded strings' do
        binary = Digest::SHA256.digest('string')

        expect(normalize(binary)).to include '�'
        expect(normalize(binary).encoding).to eql Encoding::UTF_8
        expect(normalize(binary)).to be_frozen
      end

      it 'replaces invalid characters in incorrectly encoded strings' do
        strange = Digest::SHA256.digest('string').force_encoding(Encoding::UTF_8)

        expect(normalize(strange)).to include '�'
        expect(normalize(strange).encoding).to eql Encoding::UTF_8
        expect(normalize(strange)).to be_frozen
      end

      it 'dups and freezes valid strings' do
        valid = String.new('Dönerstraße')
        expect(valid).to_not be_frozen

        expect(normalize(valid)).to eql(valid)
        # Not object-equal since the string was dup'ed
        expect(normalize(valid)).not_to equal valid
        expect(normalize(valid)).to be_frozen
      end

      it 'does not alter valid frozen strings' do
        valid = 'Dönerstraße'.freeze
        expect(normalize(valid)).to equal(valid)
      end
    end

    it 'transforms Symbol to String' do
      symbol = :foo

      expect(normalize(symbol)).to eql 'foo'
      expect(normalize(symbol).encoding).to eql Encoding::UTF_8
      expect(normalize(symbol)).to be_frozen
    end

    it 'passes Integer' do
      fixnum = 42
      expect(normalize(fixnum)).to equal fixnum
      expect(normalize(fixnum)).to be_frozen

      bignum = 10**100
      expect(normalize(bignum)).to equal bignum
      expect(normalize(bignum)).to be_frozen
    end

    it 'passes Float' do
      float = 123.456

      expect(normalize(float)).to equal float
      expect(normalize(float)).to be_frozen
    end

    it 'passes true, false, nil' do
      expect(normalize(true)).to equal true
      expect(normalize(false)).to equal false
      expect(normalize(nil)).to equal nil
    end

    describe 'with Rackstash::Fields::AbstractCollection' do
      let(:raw) { 'beepboop' }
      let(:value) {
        value = double('Rackstash::Fields::AbstractCollection')
        allow(value).to receive(:raw).and_return raw
        value
      }

      before do
        expect(Rackstash::Fields::AbstractCollection).to(
          receive(:===).with(value).and_return(true)
        )
      end

      it 'passes the collection by default' do
        expect(normalize(value)).to equal value
      end

      it 'unwraps the collection if selected' do
        expect(normalize(value, wrap: false)).to equal raw
      end
    end

    describe 'with Hash' do
      it 'wraps the hash in a Rackstash::Fields::Hash' do
        hash = { 'beep' => 'boop' }

        expect(normalize(hash)).to be_a Rackstash::Fields::Hash
        expect(normalize(hash).send(:raw)).to eql 'beep' => 'boop'
        expect(normalize(hash).send(:raw)).to_not equal hash
      end

      it 'normalizes keys to frozen UTF-8 strings' do
        hash = { 1 => 1, :two => 2, 'three' => 3, nil => 4 }

        expect(normalize(hash, wrap: false)).to eql(
          '1' => 1, 'two' => 2, 'three' => 3, '' => 4
        )
        expect(normalize(hash, wrap: false).keys).to all be_frozen
      end

      it 'returns a Concurrent::Hash with wrap: false' do
        hash = { 'one' => 1 }
        expect(normalize(hash, wrap: false)).to be_an_instance_of(Concurrent::Hash)
      end

      it 'normalizes all values' do
        hash = { 'key' => :beepboop }

        expect(collection).to receive(:normalize).with(hash).ordered
          .twice.and_call_original
        expect(collection).to receive(:normalize).with(:beepboop, anything).ordered
          .twice.and_call_original

        expect(normalize(hash)).to be_a Rackstash::Fields::Hash
        expect(normalize(hash).send(:raw)).to eql 'key' => 'beepboop'
      end

      it 'deep-wraps the hash' do
        hash = { beep: { rawr: 'growl' } }

        expect(normalize(hash)).to be_a Rackstash::Fields::Hash
        expect(normalize(hash)['beep']).to be_a Rackstash::Fields::Hash
        expect(normalize(hash)['beep']['rawr']).to eql 'growl'
      end

      it 'copies the hash' do
        raw_hash = { beep: 'boing' }
        wrapped_hash = normalize(raw_hash)

        raw_hash['foo'] = 'bar'
        expect(wrapped_hash['foo']).to be_nil
      end

      describe 'with procs' do
        it 'resolves values' do
          hash = { beep: -> { { rawr: -> { 'growl' } } } }

          expect(normalize(hash)).to be_a Rackstash::Fields::Hash
          expect(normalize(hash)['beep']).to be_a Rackstash::Fields::Hash
          expect(normalize(hash)['beep']['rawr']).to eql 'growl'
        end

        it 'resolves values with the supplied scope' do
          scope = 'scope'
          hash = { beep: -> { { self => -> { upcase } } } }

          expect(normalize(hash, scope: scope)).to be_a Rackstash::Fields::Hash
          expect(normalize(hash, scope: scope)['beep']).to be_a Rackstash::Fields::Hash
          expect(normalize(hash, scope: scope)['beep']['scope']).to eql 'SCOPE'
        end
      end
    end

    describe 'with Array' do
      it 'wraps the array in a Rackstash::Fields::Array' do
        array = ['beep', 'boop']

        expect(normalize(array)).to be_a Rackstash::Fields::Array
        expect(normalize(array).send(:raw)).to eql ['beep', 'boop']
        expect(normalize(array).send(:raw)).to_not equal array
      end

      it 'normalizes values to frozen UTF-8 strings' do
        array = [1, :two, 'three']

        expect(normalize(array, wrap: false)).to eql [1, 'two', 'three']
        expect(normalize(array, wrap: false)).to all be_frozen
      end

      it 'returns a Concurrent::Array with wrap: false' do
        array = [1, :two, 'three']
        expect(normalize(array, wrap: false)).to be_an_instance_of(Concurrent::Array)
      end

      it 'normalizes all values' do
        array = ['boop', :beep]

        expect(collection).to receive(:normalize).with(array).ordered
          .twice.and_call_original
        expect(collection).to receive(:normalize).with('boop', anything).ordered
          .twice.and_call_original
        expect(collection).to receive(:normalize).with(:beep, anything).ordered
          .twice.and_call_original

        expect(normalize(array)).to be_a Rackstash::Fields::Array
        expect(normalize(array).send(:raw)).to eql ['boop', 'beep']
      end

      it 'deep-wraps the array' do
        array = [123, ['foo', :bar]]

        expect(normalize(array)).to be_a Rackstash::Fields::Array
        expect(normalize(array)[0]).to eql 123
        expect(normalize(array)[1]).to be_a Rackstash::Fields::Array
        expect(normalize(array)[1][0]).to eql 'foo'
        expect(normalize(array)[1][1]).to eql 'bar'
      end

      it 'copies the array' do
        raw_array = [12, 'boing']
        wrapped_array = normalize(raw_array)

        raw_array[2] = 'foo'
        expect(wrapped_array[2]).to be_nil
      end

      describe 'with procs' do
        it 'resolves values' do
          array = [123, -> { ['foo', -> { :bar }] }]

          expect(normalize(array)).to be_a Rackstash::Fields::Array
          expect(normalize(array)[1]).to be_a Rackstash::Fields::Array
          expect(normalize(array)[1][1]).to eql 'bar'
        end

        it 'resolves values with the supplied scope' do
          scope = 'string'.freeze
          array = [123, -> { [upcase, -> { self }] }]

          expect(normalize(array, scope: scope)[1][0]).to eql 'STRING'
          expect(normalize(array, scope: scope)[1][1]).to eql scope
        end
      end

      it 'resolves a proc returning an array' do
        expect(normalize(-> { ['foo'] })).to be_instance_of Rackstash::Fields::Array
        expect(normalize(-> { ['foo'] })).to contain_exactly 'foo'
      end

      it 'resolves nested procs' do
        expect(normalize(-> { [-> { 'foo' }] })).to be_instance_of Rackstash::Fields::Array
        expect(normalize(-> { [-> { 'foo' }] })).to contain_exactly 'foo'
      end

      it 'returns a raw array returned from a proc with wrap: false' do
        expect(normalize(-> { ['foo'] }, wrap: false)).to be_a ::Array
        expect(normalize(-> { ['foo'] }, wrap: false)).to eql ['foo']
      end

      it 'returns a raw array returned from a nested proc with wrap: false' do
        expect(normalize(-> { [-> { 'foo' }] }, wrap: false)).to be_a ::Array
        expect(normalize(-> { [-> { 'foo' }] }, wrap: false)).to eql ['foo']
      end
    end

    it 'wraps an Enumerator in a Rackstash::Fields::Array' do
      small_numbers = Enumerator.new do |y|
        3.times do |i|
          y << i
        end
      end
      expect(normalize(small_numbers)).to be_a Rackstash::Fields::Array
      expect(normalize(small_numbers).send(:raw)).to eql [0, 1, 2]
    end

    it 'formats Time as an ISO 8601 UTC timestamp' do
      time = Time.parse('2016-10-17 16:37:42 +03:00')

      expect(normalize(time)).to eql '2016-10-17T13:37:42.000Z'
      expect(normalize(time).encoding).to eql Encoding::UTF_8
      expect(normalize(time)).to be_frozen
    end

    it 'formats DateTime as an ISO 8601 UTC timestamp' do
      datetime = DateTime.parse('2016-10-17 15:37:42 CEST') # UTC +02:00

      expect(normalize(datetime)).to eql '2016-10-17T13:37:42.000Z'
      expect(normalize(datetime).encoding).to eql Encoding::UTF_8
      expect(normalize(datetime)).to be_frozen
    end

    it 'formats Date as an ISO 8601 date string' do
      date = Date.new(2016, 10, 17)

      expect(normalize(date)).to eql '2016-10-17'
      expect(normalize(date).encoding).to eql Encoding::UTF_8
      expect(normalize(date)).to be_frozen
    end

    it 'transforms Regexp to String' do
      regexp = /.?|(..+?)\1+/

      expect(normalize(regexp)).to eql '(?-mix:.?|(..+?)\1+)'
      expect(normalize(regexp).encoding).to eql Encoding::UTF_8
      expect(normalize(regexp)).to be_frozen
    end

    it 'transforms Range to String' do
      range = (1..10)

      expect(normalize(range)).to eql '1..10'
      expect(normalize(range).encoding).to eql Encoding::UTF_8
      expect(normalize(range)).to be_frozen
    end

    it 'transforms URI to String' do
      uris = {
        URI('https://example.com/p/f.txt') => 'https://example.com/p/f.txt',
        URI('') => ''
      }

      uris.each do |uri, result|
        expect(uri).to be_a URI::Generic

        expect(normalize(uri)).to eql result
        expect(normalize(uri).encoding).to eql Encoding::UTF_8
        expect(normalize(uri)).to be_frozen
      end
    end

    it 'transforms URI to String' do
      uris = {
        URI('https://example.com/p/f.txt') => 'https://example.com/p/f.txt',
        URI('') => ''
      }

      uris.each do |uri, result|
        expect(uri).to be_a URI::Generic

        expect(normalize(uri)).to eql result
        expect(normalize(uri).encoding).to eql Encoding::UTF_8
        expect(normalize(uri)).to be_frozen
      end
    end

    it 'transforms Pathname to String' do
      pathname = Pathname.new('/path/to/file.ext'.encode(Encoding::ISO8859_9))

      expect(normalize(pathname)).to eql '/path/to/file.ext'
      expect(normalize(pathname).encoding).to eql Encoding::UTF_8
      expect(normalize(pathname)).to be_frozen
    end

    it 'formats an Exception with Backtrace' do
      exception = nil
      begin
        raise StandardError, 'An Error'
      rescue => e
        exception = e
      end

      checker = Regexp.new <<-EOF.gsub(/^\s+/, '').rstrip, Regexp::MULTILINE
        \\AAn Error \\(StandardError\\)
        #{Regexp.escape __FILE__}:#{__LINE__ - 7}:in `block .*`
      EOF
      expect(normalize(exception)).to match checker
      expect(normalize(exception).encoding).to eql Encoding::UTF_8
      expect(normalize(exception)).to be_frozen
    end

    it 'transforms BigDecimal to String' do
      bigdecimal = BigDecimal.new('123.987653')

      expect(normalize(bigdecimal)).to eql '123.987653'
      expect(normalize(bigdecimal).encoding).to eql Encoding::UTF_8
      expect(normalize(bigdecimal)).to be_frozen
    end

    describe 'with Proc' do
      it 'calls the proc by default and normalizes the result' do
        proc = -> { :return }

        expect(normalize(proc)).to eql 'return'
        expect(normalize(proc).encoding).to eql Encoding::UTF_8
        expect(normalize(proc)).to be_frozen
      end

      it 'calls a nested proc and normalizes the result' do
        inner = -> { :return }
        outer = -> { inner }

        expect(normalize(outer)).to eql 'return'
      end

      it 'returns the inspected proc on errors' do
        error = -> { raise 'Oh, no!' }
        expected_arguments = ->(arg1, args, arg3) { 'cherio' }
        ok = -> { :ok }
        outer = -> { [ok, error, expected_arguments] }

        expect(normalize(outer))
          .to be_a(Rackstash::Fields::Array)
          .and contain_exactly('ok', error.inspect, expected_arguments.inspect)
      end
    end

    it 'transforms Complex to String' do
      complex = Complex(2, 3)

      expect(normalize(complex)).to eql '2+3i'
      expect(normalize(complex).encoding).to eql Encoding::UTF_8
      expect(normalize(complex)).to be_frozen
    end

    it 'transforms Rational to Float' do
      rational = Rational(-8, 6)

      expect(normalize(rational)).to be_a Float
      expect(normalize(rational)).to be_frozen
    end

    context 'conversion methods' do
      let(:methods) {
        %i[as_json to_hash to_ary to_h to_a to_time to_datetime to_date to_f to_i]
      }

      it 'attempts conversion to base objects in order' do
        methods.each_with_index do |method, i|
          obj = double("#{method} - successful")

          methods[0..i].each_with_index do |check, j|
            expect(obj).to receive(:respond_to?).with(check).and_return(i == j)
              .ordered.once
          end

          expect(obj).to receive(method).and_return("obj with #{method}")
            .ordered.once
          expect(normalize(obj)).to eql "obj with #{method}"
        end
      end

      it 'falls back on conversion error' do
        obj = double('erroneous')

        methods.each do |method|
          expect(obj).to receive(:respond_to?).with(method).and_return(true)
            .ordered.once
          expect(obj).to receive(method).and_raise('foo').ordered.once
        end

        expect(obj).to receive(:inspect).and_return 'finally'
        expect(normalize(obj)).to eql 'finally'
      end

      it 'inspects objects we don\'t have a special rule for' do
        obj = double('any object')
        expect(obj).to receive(:inspect).and_return('an object')

        expect(normalize(obj)).to eql 'an object'
      end
    end
  end

  describe '#to_s' do
    it 'inspects #as_json' do
      as_json = double('JSON value')
      expect(collection).to receive(:as_json).and_return(as_json)
      expect(as_json).to receive(:inspect)

      collection.to_s
    end
  end
end
