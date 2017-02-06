# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/fields/abstract_collection'

module Rackstash
  module Fields
    class Hash < AbstractCollection
      def initialize(forbidden_keys: EMPTY_SET)
        @raw = {}

        if forbidden_keys.is_a?(Set)
          forbidden_keys = forbidden_keys.dup.freeze unless forbidden_keys.frozen?
          @forbidden_keys = forbidden_keys
        else
          @forbidden_keys = Set[*forbidden_keys].freeze
        end
      end

      # @param key [#to_s] the key name. We will always use it as a
      #   frozen UTF-8 String.
      # @return [Object, nil] the current value of the field or `nil` if the
      #   field wasn't set (yet)
      def [](key)
        @raw[utf8_encode(key)]
      end

      # Set the value of a key to the supplied value
      #
      # You can set nested hashes and arrays here. The hash keys will be
      # normalized as strings.
      #
      # @param key [#to_s] the field name. When setting the field, this name
      #   will be normalized as a frozen UTF-8 string.
      # @param value [#call, Object] any value which can be serialized to JSON.
      #   The value will be normalized before being insert so that only JSON-
      #   compatible objects are inserted into the Hash.
      #
      # @raise [ArgumentError] if you attempt to set one of the forbidden keys.
      # @return [void]
      def []=(key, value)
        key = utf8_encode(key)
        raise ArgumentError, "Forbidden field #{key}" if forbidden_key?(key)

        @raw[key] = normalize(value)
      end
      alias :store :[]=

      # @return [::Hash] deep-transforms the hash into a plain Ruby Hash
      def as_json(*)
        @raw.each_with_object({}) do |(key, value), memo|
          value = value.as_json if value.is_a?(AbstractCollection)
          memo[key] = value
        end
      end
      alias :to_hash :as_json
      alias :to_h :as_json

      # Removes all key-value pairs from `self`.
      #
      # @return [self]
      def clear
        @raw.clear
        self
      end

      # @return [Boolean] `true` if the Hash contains no ley-value pairs,
      #   `false` otherwise.
      def empty?
        @raw.empty?
      end

      # @return [::Array] a new array populated with the keys from this hash.
      # @see #values
      def keys
        @raw.keys
      end

      # Returns a new {Hash} containing the contents of hash and the contents of
      # `self`. If no block is specified, the value for entries with duplicate
      # keys will be that of hash. Otherwise the value for each duplicate key
      # is determined by calling the block with the `key`, its value in `self`
      # and its value in `hash`.
      #
      # If there are any forbidden fields defined on `self`, An `ArgumentError`
      # is raised when trying to set any of these. The values are ignored of
      # `force` is set to `false`.
      #
      # If `hash` itself of any of its (deeply-nested) values is a proc, it will
      # get called and its result will be used instead of it. The proc will be
      # evaluated in the instance scope of `scope` if given.
      #
      # @param hash [::Hash, Hash, Proc] the hash to merge into `self`. If this
      #   is a proc, it will get called and its result is used instead
      # @param force [Boolean] `true` to raise an `ArgumentError` when trying to
      #   set a forbidden key, `false` to silently ingnore these key-value pairs
      # @param scope [Object] if `hash` or any of its (deeply-nested) values is
      #   a proc, it will be called in the instance scope of this object.
      #
      # @yield [key, old_val, new-val] if a block is given and there is a
      #   duplicate key, we call the block and use its return value as the value
      #   to insert
      # @yieldparam key [String] the hash key
      # @yieldparam old_val [Object] The existing value for `key` in `self`
      # @yieldparam new_val [Object] The new normalized value for `key` in
      #   `hash`
      # @yieldreturn [Object] the intended new value for `key` to be merged into
      #   `self` at `key`.
      #
      # @raise [ArgumentError] if you attempt to set one of the forbidden fields
      #   and `force` is `true`
      #
      # @return [Hash] a new hash containing the merged key-value pairs
      def merge(hash, force: true, scope: nil, &block)
        dup.merge!(hash, force: force, scope: scope, &block)
      end

      # Adds the contents of hash to `self`. `hash` is normalized before being
      # added. If no block is specified, entries with duplicate keys are
      # overwritten with the values from `hash`, otherwise the value of each
      # duplicate key is determined by calling the block with the `key`, its
      # value in `self` and its value in `hash`.
      #
      # If there are any forbidden fields defined on `self`, An `ArgumentError`
      # is raised when trying to set any of these. The values are ignored of
      # `force` is set to `false`.
      #
      # If `hash` itself of any of its (deeply-nested) values is a proc, it will
      # get called and its result will be used instead of it. The proc will be
      # evaluated in the instance scope of `scope` if given.
      #
      # @param hash [::Hash, Hash, Proc] the hash to merge into `self`. If this
      #   is a proc, it will get called and its result is used instead
      # @param force [Boolean] `true` to raise an `ArgumentError` when trying to
      #   set a forbidden key, `false` to silently ingnore these key-value pairs
      # @param scope [Object] if `hash` or any of its (deeply-nested) values is
      #   a proc, it will be called in the instance scope of this object.
      #
      # @yield [key, old_val, new-val] if a block is given and there is a
      #   duplicate key, we call the block and use its return value as the value
      #   to insert
      # @yieldparam key [String] the hash key
      # @yieldparam old_val [Object] The existing value for `key` in `self`
      # @yieldparam new_val [Object] The new normalized value for `key` in
      #   `hash`
      # @yieldreturn [Object] the intended new value for `key` to be merged into
      #   `self` at `key`.
      #
      # @raise [ArgumentError] if you attempt to set one of the forbidden fields
      #   and `force` is `true`
      #
      # @return [self]
      def merge!(hash, force: true, scope: nil)
        hash = Hash(normalize(hash, scope: scope, wrap: false))

        if force
          forbidden = @forbidden_keys & hash.keys
          unless forbidden.empty?
            raise ArgumentError, "Forbidden keys #{forbidden.to_a.join(', ')}"
          end
        else
          hash = hash.reject { |k, _v| forbidden_key?(k) }
        end

        if block_given?
          @raw.merge!(hash) { |key, old_val, new_val|
            yielded = yield(key, old_val, new_val)
            normalize(yielded, scope: scope)
          }
        else
          @raw.merge!(hash)
        end
        self
      end
      alias :update :merge!

      # @param key [String] The name of a key to check. This MUST be a correctly
      #   encoded String in order to return valid results
      # @return [Boolean] `true` if the key is forbidden from being added
      def forbidden_key?(key)
        @forbidden_keys.include?(key)
      end

      # @return [::Array] a new array populated with the values from this hash.
      # @see #keys
      def values
        @raw.values
      end

      private

      def Hash(obj)
        return obj.to_hash if obj.respond_to?(:to_hash)
        raise TypeError, "no implicit conversion of #{obj.class} into Hash"
      end
    end

    def self.Hash(raw, forbidden_keys: EMPTY_SET)
      Rackstash::Fields::Hash.new(forbidden_keys: forbidden_keys).merge!(raw)
    end
  end
end
