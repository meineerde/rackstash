# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/fields/abstract_collection'

module Rackstash
  module Fields
    class Array < AbstractCollection
      def initialize
        @raw = Concurrent::Array.new
      end

      # @!method +(array)
      #   Concatenation -- Returns a new {Rackstash::Fields::Array} built by
      #   concatenating `self` and  the given `array` together to produce a
      #   third array.
      #
      #   @param array [::Array, Rackstash::Fields::Array, Proc]
      #   @return [Rackstash::Fields::Array]

      # @!method -(array)
      #   Array Difference -- Returns a new {Rackstash::Fields::Array} that is a
      #   copy of `self`, removing any items that also appear in the given
      #   `array`. The order is preserved from `self`.
      #
      #   @param array [::Array, Rackstash::Fields::Array, Proc]
      #   @return [Rackstash::Fields::Array]

      # @!method |(array)
      #   Set Union -- Returns a new {Rackstash::Fields::Array} by joining `self`
      #   with the given `array`, excluding any duplicates and preserving the
      #   order from `self`.
      #
      #   @param array [::Array, Rackstash::Fields::Array, Proc]
      #   @return [Rackstash::Fields::Array]

      # @!method &(array)
      #   Set Intersection -- Returns a new {Rackstash::Fields::Array} containing
      #   elements common to `self` and the given `array`, excluding any
      #   duplicates. The order is preserved from `self`.
      #
      #   @param array [::Array, Rackstash::Fields::Array, Proc]
      #   @return [Rackstash::Fields::Array]

      %i[+ - | &].each do |op|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{op}(array)
            new(@raw #{op} normalize(array, wrap: false))
          end
        RUBY
      end

      # Returns the element at `index`, or returns a subarray starting at the
      # `start` index and continuing for `length` elements, or returns a subarray
      # specified by `range` of indices.
      #
      # Negative indices count backward from the end of the array (-1 is the
      # last element). For `start` and `range` cases the starting index is just
      # before an element. Additionally, an empty array is returned when the
      # starting index for an element range is at the end of the array.
      #
      # Returns `nil` if the index (or starting index) are out of range.
      # @return [Object, nil]
      #
      # @overload [](index)
      #   Returns the element at `index`
      #
      #   @param index [Integer] the index in the array where we fetch the value
      #   @return [Object, nil] the current value at `index` or `nil` if no
      #     value could be found
      #
      # @overload [](start, length)
      #   Returns an {Array} starting at the `start` index and continuing for
      #   `length` elements
      #
      #   @param start [Integer] the index in the array where we fetch the
      #     first value
      #   @param length [Integer] the number of elements to return
      #   @return [Array, nil] the current value at `index` or `nil` if `start`
      #     is out of range
      #
      # @overload [](range)
      #   Returns an {Array} starting at the `start` index and continuing for
      #   `length` elements
      #
      #   @param range [Range] specifies the range of elements to return from
      #     the array
      #   @return [Array, nil] the current value at `index` or `nil` if the
      #     start index is out of range
      def [](index, length = nil)
        result = length.nil? ? @raw[index] : @raw[index, length]
        result = new(result) if ::Concurrent::Array === result
        result
      end
      alias slice []

      # Element Assignment - Sets the element at `index`, or replaces a subarray
      # from the `start` index for `length` elements, or replaces a subarray
      # specified by the `range` of indices.
      #
      # All values are normalized before being set. You can set nested hashes
      # and arrays here.
      #
      # If indices are greater than the current capacity of the array, the array
      # grows automatically. Elements are inserted into the array at start if
      # length is zero.
      #
      # Negative indices will count backward from the end of the array. For
      # `start` and `range` cases the starting index is just before an element.
      #
      # An `IndexError` is raised if a negative index points past the beginning
      # of the array.
      #
      # See also {#push}, and {#unshift}.
      #
      # @overload []=(index, value)
      #   @param index [Integer] the index in the array where we set the value
      #   @param value [Object, Proc] any value which can be serialized to JSON.
      #     The value will be normalized before being set so that only JSON-
      #     compatible objects are added into the array. A given Proc is called
      #     with its result being used instead.
      #
      # @overload []=(range, value)
      #   Replaces a subarray specified by the range of indices.
      #
      #   @param range [Range] the range if values in `self` which are replaced
      #     by the passed `value`
      #   @param value [Array, ::Array, #to_ary, Proc] An array contining
      #     JSON-serializable values. The value will be normalized before being
      #     set so that only JSON-compatible objects are added into the array. A
      #     given Proc is called with its result being used instead.
      #
      # @overload []=(start, length, value)
      #   Replaces a subarray from the `start` index for `length` elements with
      #   the passed `value`.
      #
      #   @param index [Integer] the index in the array where we set the value
      #   @param length [Integer] the index in the array where we set the value
      #   @param value [Array, ::Array, #to_ary, Proc] An array contining
      #     JSON-serializable values. The value will be normalized before being
      #     set so that only JSON-compatible objects are added into the array. A
      #     given Proc is called with its result being used instead.
      #
      # @return [value]
      def []=(index, value_or_length, value = UNDEFINED)
        if UNDEFINED.equal?(value)
          @raw[index] = normalize(value_or_length)
        else
          @raw[index, value_or_length] = implicit(normalize(value, wrap: false))
        end
      end

      # Add a given value at the end of the array
      #
      # @param value [Object, Proc] any value which can be serialized to JSON.
      #   The value will be normalized before being added so that only JSON-
      #   compatible objects are added into the array.
      # @return [self]
      def <<(value)
        @raw << normalize(value)
        self
      end

      # @return [::Array] deep-transforms the array into a plain Ruby Array
      def as_json(*)
        @raw.to_a.map! { |value|
          value.is_a?(AbstractCollection) ? value.as_json : value
        }
      end
      alias to_ary as_json
      alias to_a as_json

      # Removes all elements from `self`.
      #
      # @return [self]
      def clear
        @raw.clear
        self
      end

      # Appends the elements of `array` to self.
      #
      # @param array [Array, ::Array, Proc] an array of values. Each value is
      #   normalized before being added to `self`.
      # @param scope [Object, nil] if `array` or any of its (deeply-nested)
      #   values is a proc, it will be called in the instance scope of this
      #   object (when given).
      # @return [self]
      def concat(array, scope: nil)
        array = implicit(normalize(array, wrap: false, scope: scope))
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
      alias size length

      # Set Union -- Add value from `array` to `self` excluding any duplicates
      # and preserving the order from `self`.
      #
      # @param array [Array, ::Array, Proc] an array of values. Each value is
      #   normalized before being added to `self`.
      # @param scope [Object, nil] if `array` or any of its (deeply-nested)
      #   values is a proc, it will be called in the instance scope of this
      #   object (when given).
      # @return [self]
      #
      # @see #|
      # @see #merge!
      def merge(array, scope: nil)
        new(@raw | normalize(array, wrap: false, scope: scope))
      end

      # Set Union -- Add value from `array` to `self` excluding any duplicates
      # and preserving the order from `self`.
      #
      # @param array [Array, ::Array, Proc] an array of values. Each value is
      #   normalized before being added to `self`.
      # @param scope [Object, nil] if `array` or any of its (deeply-nested)
      #   values is a proc, it will be called in the instance scope of this
      #   object (when given).
      # @return [self]
      #
      # @see #merge
      def merge!(array, scope: nil)
        @raw.replace(@raw | normalize(array, wrap: false, scope: scope))
        self
      end

      # Removes the last element from `self` and returns it, or `nil` if the
      # array is empty. If a number `n` is given, returns an array of the last
      # `n` elements (or less).
      #
      # See {#push} for the opposite effect.
      #
      # @param n [Integer, nil] the (optional) number of elements to return from
      #   the end
      # @return [Object, Array<Object>, nil] If `n` was given, we always return
      #   an array with at most `n` elements. Else, we return the last element
      #   or `nil` if the array is empty.
      #
      def pop(n = nil)
        n.nil? ? @raw.pop : @raw.pop(n)
      end

      # Append — Pushes the given object(s) on to the end of this array. All
      # values will be normalized before being added. This method returns the
      # array itself, so several appends may be chained together.
      #
      # @param values [::Array] a list of values to append at the end of `self`
      # @param scope [Object, nil] if any of the (deeply-nested) values is a
      #   proc, it will be called in the instance scope of this object (when
      #   given).
      # @return [self]
      def push(*values, scope: nil)
        concat(values, scope: scope)
      end
      alias append push

      private

      def implicit(obj)
        return obj.to_ary if obj.respond_to?(:to_ary)
        raise TypeError, "no implicit conversion of #{obj.class} into Array"
      end
    end

    def self.Array(array)
      Rackstash::Fields::Array.new.concat(array)
    end
  end
end
