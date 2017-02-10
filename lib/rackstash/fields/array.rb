# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/fields/abstract_collection'

module Rackstash
  module Fields
    class Array < AbstractCollection
      def initialize
        @raw = []
      end

      # Retrieve a stored value from a given `index`
      #
      # @param index [Integer] the index in the array where we fetch the value
      # @return [Object, nil] the current value at `index` or `nil` if no value
      #   could be found
      def [](index)
        @raw[index]
      end

      # Set the value at a given index to the supplied value. The value is
      # normalized before being set.
      #
      # You can set nested hashes and arrays here.
      #
      # @param index [Integer] the index in the array where we fetch the value
      # @param value [#call, Object] any value which can be serialized to JSON.
      #   The value will be normalized before being set so that only JSON-
      #   compatible objects are added into the array.
      # @return [void]
      def []=(index, value)
        @raw[index] = normalize(value)
      end

      # Add a given value at the end of the array
      #
      # @param value [#call, Object] any value which can be serialized to JSON.
      #   The value will be normalized before being added so that only JSON-
      #   compatible objects are added into the array.
      # @return [self]
      def <<(value)
        @raw << normalize(value)
        self
      end

      # @return [::Array] deep-transforms the array into a plain Ruby Array
      def as_json(*)
        @raw.map { |value|
          value.is_a?(AbstractCollection) ? value.as_json : value
        }
      end
      alias :to_ary :as_json
      alias :to_a :as_json

      # Removes all elements from `self`.
      #
      # @return [self]
      def clear
        @raw.clear
        self
      end

      # Appends the elements of `array` to self.
      #
      # @param array [Array, ::Array] an array of values. Each value is
      #   normalized before being added to `self`.
      # @return [self]
      def concat(array)
        array = Array(normalize(array, wrap: false))
        @raw.concat(array)
        self
      end

      # @return [Boolean] `true` if `self` contain no elements
      def empty?
        @raw.empty?
      end

      # @return [Integer] the number of elements in `self`
      def length
        @raw.length
      end

      private

      def Array(obj)
        return obj.to_ary if obj.respond_to?(:to_ary)
        raise TypeError, "no implicit conversion of #{obj.class} into Array"
      end
    end

    def self.Array(array)
      Rackstash::Fields::Array.new.concat(array)
    end
  end
end
