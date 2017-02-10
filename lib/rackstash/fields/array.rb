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

      def [](index)
        @raw[index]
      end

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

      def as_json(*)
        @raw.map { |value|
          value.is_a?(AbstractCollection) ? value.as_json : value
        }
      end
      alias :to_ary :as_json
      alias :to_a :as_json

      def clear
        @raw.clear
        self
      end

      def concat(array)
        array = Array(normalize(array, wrap: false))
        @raw.concat(array)
        self
      end

      def empty?
        @raw.empty?
      end

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
