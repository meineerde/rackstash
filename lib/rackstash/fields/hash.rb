# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/fields/abstract_collection'

module Rackstash
  module Fields
    class Hash < AbstractCollection
      # @param forbidden_keys [Set<String>,::Array<String>] a list of strings
      #   which are not allowed to be used as keys in this hash
      def initialize(forbidden_keys: EMPTY_SET)
        @raw = Concurrent::Hash.new

        if forbidden_keys.is_a?(Set)
          forbidden_keys = forbidden_keys.dup.freeze unless forbidden_keys.frozen?
          @forbidden_keys = forbidden_keys
        else
          @forbidden_keys = Set[*forbidden_keys].freeze
        end
      end

      # Retrieve a stored value from a given `key`
      #
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
      # @param value [Proc, Object] any value which can be serialized to JSON.
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
      alias store []=

      # @return [::Hash] deep-transforms the hash into a plain Ruby Hash
      def as_json(*)
        @raw.each_with_object({}) do |(key, value), memo|
          value = value.as_json if value.is_a?(AbstractCollection)
          memo[key] = value
        end
      end
      alias to_hash as_json
      alias to_h as_json

      # Removes all key-value pairs from `self`.
      #
      # @return [self]
      def clear
        @raw.clear
        self
      end

      # Returns a new {Hash} containing the contents of `hash` and the contents
      # of `self`. `hash` is normalized before being added. In contrast to
      # {#merge}, this method deep-merges Hash and Array values if the existing
      # and merged values are of the same type.
      #
      # If the value is a callable object (e.g. a proc or lambda), we will call
      # it and use the returned value instead, which must then be a Hash of
      # course. If any of the values of the hash is a proc, it will also be
      # called and the return value will be used.
      #
      # If you give the optional `scope` argument, the Procs will be evaluated
      # in the instance scope of this object. If you leave the `scope` empty,
      # they will be called in the scope of their creation environment.
      #
      # The following examples are thus all equivalent:
      #
      #     empty_hash.deep_merge 'foo' => 'bar'
      #     empty_hash.deep_merge 'foo' => -> { 'bar' }
      #     empty_hash.deep_merge -> { 'foo' => 'bar' }
      #     empty_hash.deep_merge -> { 'foo' => -> { 'bar' } }
      #     empty_hash.deep_merge({ 'foo' => -> { self } }, scope: 'bar')
      #     empty_hash.deep_merge -> { { 'foo' => -> { self } } }, scope: 'bar'
      #
      # Nested hashes will be deep-merged and all field names will be normalized
      # to strings, even on deeper levels. Given an empty Hash, these calls
      #
      #     empty_hash.merge! 'foo' => { 'bar' => 'baz' }
      #     empty_hash.deep_merge 'foo' => { 'bar' => 'qux', fizz' => 'buzz' }
      #
      # will be equivalent to a single call of
      #
      #     empty_hash.deep_merge 'foo' => { 'bar' => 'qux', fizz' => 'buzz' }
      #
      # As you can see, the new `"qux"` value of the nested `"bar"` field
      # overwrites the old `"baz"` value.
      #
      # When setting the `force` argument to `false`, we will not overwrite
      # existing leaf value anymore but will just ignore the value. We will
      # still attempt to merge nested Hashes and Arrays if the existing and new
      # values are compatible. Thus, given an empty Hash, these calls
      #
      #     empty_hash.merge!({ 'foo' => { 'bar' => 'baz' } }, force: false)
      #     empty_hash.deep_merge({ 'foo' => { 'bar' => 'qux', fizz' => 'buzz' } }, force: false)
      #
      # will be equivalent to a single call of
      #
      #     empty_hash.deep_merge({ 'foo' => { 'bar' => 'baz', fizz' => 'buzz' } })
      #
      # With `force: false` the new `"qux"` value of the nested `"bar"` field is
      # ignored since it was already set. We will ignore any attempt to
      # overwrite any existing non-nil value.
      #
      # @param hash (see #merge)
      # @param force (see #merge)
      # @param scope (see #merge)
      # @raise [ArgumentError] if you attempt to set one of the forbidden fields
      #   and `force` is `true`
      # @return [Rackstash::Fields::Hash] a new hash containing the merged
      #   key-value pairs
      #
      # @see #merge
      # @see #deep_merge!
      def deep_merge(hash, force: true, scope: nil)
        resolver = deep_merge_resolver(:merge, force: force)
        merge(hash, force: force, scope: scope, &resolver)
      end

      # Adds the contents of `hash` to `self`. `hash` is normalized before being
      # added. In contrast to {#merge!}, this method deep-merges Hash and Array
      # values if the existing and merged values are of the same type.
      #
      # If the value is a callable object (e.g. a proc or lambda), we will call
      # it and use the returned value instead, which must then be a Hash of
      # course. If any of the values of the hash is a proc, it will also be
      # called and the return value will be used.
      #
      # If you give the optional `scope` argument, the Procs will be evaluated
      # in the instance scope of this object. If you leave the `scope` empty,
      # they will be called in the scope of their creation environment.
      #
      # The following examples are thus all equivalent:
      #
      #     empty_hash.deep_merge! 'foo' => 'bar'
      #     empty_hash.deep_merge! 'foo' => -> { 'bar' }
      #     empty_hash.deep_merge! -> { 'foo' => 'bar' }
      #     empty_hash.deep_merge! -> { 'foo' => -> { 'bar' } }
      #     empty_hash.deep_merge!({ 'foo' => -> { self } }, scope: 'bar')
      #     empty_hash.deep_merge! -> { { 'foo' => -> { self } } }, scope: 'bar'
      #
      # Nested hashes will be deep-merged and all field names will be normalized
      # to strings, even on deeper levels. Given an empty Hash, these calls
      #
      #     empty_hash.merge! 'foo' => { 'bar' => 'baz' }
      #     empty_hash.deep_merge! 'foo' => { 'bar' => 'qux', fizz' => 'buzz' }
      #
      # will be equivalent to a single call of
      #
      #     empty_hash.deep_merge! 'foo' => { 'bar' => 'qux', fizz' => 'buzz' }
      #
      # As you can see, the new `"qux"` value of the nested `"bar"` field
      # overwrites the old `"baz"` value.
      #
      # When setting the `force` argument to `false`, we will not overwrite
      # existing leaf value anymore but will just ignore the value. We will
      # still attempt to merge nested Hashes and Arrays if the existing and new
      # values are compatible. Thus, given an empty Hash, these calls
      #
      #     empty_hash.merge!({ 'foo' => { 'bar' => 'baz' } }, force: false)
      #     empty_hash.deep_merge!({ 'foo' => { 'bar' => 'qux', fizz' => 'buzz' } }, force: false)
      #
      # will be equivalent to a single call of
      #
      #     empty_hash.deep_merge!({ 'foo' => { 'bar' => 'baz', fizz' => 'buzz' } })
      #
      # With `force: false` the new `"qux"` value of the nested `"bar"` field is
      # ignored since it was already set. We will ignore any attempt to
      # overwrite any existing non-nil value.
      #
      # @param hash (see #merge!)
      # @param force (see #merge!)
      # @param scope (see #merge!)
      # @raise [ArgumentError] if you attempt to set one of the forbidden fields
      #   and `force` is `true`
      # @return [self]
      #
      # @see #merge!
      # @see #deep_merge
      def deep_merge!(hash, force: true, scope: nil)
        resolver = deep_merge_resolver(:merge!, force: force)
        merge!(hash, force: force, scope: scope, &resolver)
      end

      # @return [Boolean] `true` if the Hash contains no ley-value pairs,
      #   `false` otherwise.
      def empty?
        @raw.empty?
      end

      # @param key [String] The name of a key to check. This MUST be a correctly
      #   encoded String in order to return valid results
      # @return [Boolean] `true` if the key is forbidden from being added
      def forbidden_key?(key)
        @forbidden_keys.include?(key)
      end

      # Returns true if the given key is present in `self`.
      #
      #     h = Rackstash::Fields::Hash.new
      #     h.merge!({ "a" => 100, "b" => 200 })
      #
      #     h.key?("a")   #=> true
      #     h.key?("z")   #=> false
      #
      # @param key [#to_s] the field name. The key will be converted to an
      #   UTF-8 string before being checked.
      # @return [Boolean] `true` if the normalized key is present in `self`
      def key?(key)
        @raw.key? utf8_encode(key)
      end
      alias has_key? key?
      alias include? key?
      alias member? key?

      # @return [::Array<String>] a new array populated with the keys from this
      #   hash.
      # @see #values
      def keys
        @raw.keys
      end

      # Returns a new {Hash} containing the contents of `hash` and of
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
      # @param hash [::Hash<#to_s, => Proc, Object>, Rackstash::Fields::Hash, Proc]
      #   the hash to merge into `self`. If this is a proc, it will get called
      #   and its result is used instead.
      # @param force [Boolean] `true` to raise an `ArgumentError` when trying to
      #   set a forbidden key, `false` to silently ingnore these key-value pairs
      # @param scope [Object, nil] if `hash` or any of its (deeply-nested)
      #   values is a proc, it will be called in the instance scope of this
      #   object (when given).
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
      # @raise [ArgumentError] if you attempt to set one of the forbidden fields
      #   and `force` is `true`
      # @return [Rackstash::Fields::Hash] a new hash containing the merged
      #   key-value pairs
      def merge(hash, force: true, scope: nil)
        if block_given?
          dup.merge!(hash, force: force, scope: scope) { |key, old_val, new_val|
            yield key, old_val, new_val
          }
        else
          dup.merge!(hash, force: force, scope: scope)
        end
      end

      # Adds the contents of `hash` to `self`. `hash` is normalized before being
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
      # @param hash [::Hash<#to_s, => Proc, Object>, Rackstash::Fields::Hash, Proc]
      #   the hash to merge into `self`. If this is a proc, it will get called
      #   and its result is used instead
      # @param force [Boolean] `true` to raise an `ArgumentError` when trying to
      #   set a forbidden key, `false` to silently ingnore these key-value pairs
      # @param scope [Object, nil] if `hash` or any of its (deeply-nested)
      #   values is a proc, it will be called in the instance scope of this
      #   object (when given).
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
      # @raise [ArgumentError] if you attempt to set one of the forbidden fields
      #   and `force` is `true`
      # @return [self]
      def merge!(hash, force: true, scope: nil)
        hash = implicit(normalize(hash, scope: scope, wrap: false))

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
      alias update merge!


      # Returns a new {Hash} containing the contents of `hash` and the contents
      # of `self`. `hash` is normalized before being added. In contrast to
      # {#merge}, this method preserves any non-nil values of existing keys in
      # `self` in the returned hash.
      #
      # If `hash` is a callable object (e.g. a proc or lambda), we will call
      # it and use the returned value instead, which must then be a Hash of
      # course. If any of the values of the hash is a proc, it will also be
      # called and the return value will be used.
      #
      # If you give the optional `scope` argument, the Procs will be evaluated
      # in the instance scope of this object. If you leave the `scope` empty,
      # they will be called in the scope of their creation environment.
      #
      # @param hash (see #merge)
      # @param scope (see #merge)
      # @return [Rackstash::Fields::Hash] a new hash containing the merged
      #   key-value pairs
      #
      # @see #merge
      # @see #reverse_merge!
      def reverse_merge(hash, scope: nil)
        merge(hash, force: false, scope: scope) { |_key, old_val, new_val|
          old_val == nil ? new_val : old_val
        }
      end

      # Adds the contents of `hash` to `self`. `hash` is normalized before being
      # added. In contrast to {#merge!}, this method deep-merges Hash and Array
      # values if the existing and merged values are of the same type.
      #

      # Returns a new {Hash} containing the contents of `hash` and the contents
      # of `self`. `hash` is normalized before being added. In contrast to
      # {#merge}, this method preserves any non-nil values of existing keys in
      # `self`.
      #
      # If `hash` is a callable object (e.g. a proc or lambda), we will call
      # it and use the returned value instead, which must then be a Hash of
      # course. If any of the values of the hash is a proc, it will also be
      # called and the return value will be used.
      #
      # If you give the optional `scope` argument, the Procs will be evaluated
      # in the instance scope of this object. If you leave the `scope` empty,
      # they will be called in the scope of their creation environment.
      #
      # @param hash (see #merge!)
      # @param scope (see #merge!)
      # @return [self]
      #
      # @see #merge!
      # @see #reverse_merge
      def reverse_merge!(hash, scope: nil)
        merge!(hash, force: false, scope: scope) { |_key, old_val, new_val|
          old_val == nil ? new_val : old_val
        }
      end
      alias reverse_update reverse_merge!

      # Set a `key` of `self` to the returned value of the passed block.
      # If the key is forbidden from being set or already exists with a value
      # other than `nil`, the block will not be called and the value will not be
      # set.
      #
      # @param key [#to_s] the field name. When setting the field, this name
      #   will be normalized as a frozen UTF-8 string.
      #
      # @yield [key] if the key doesn't exist yet, we call the block and use its
      #    return value as the value to insert at `key`
      # @yieldparam key [String] The normalized key where the value is being
      #    inserted
      # @yieldreturn [Proc, Object] the intended new value for `key` to be
      #   merged into `self` at `key`.
      #
      # @return [Object, nil] The return value of the block or `nil` if no
      #   insertion happened. Note that `nil` is also a valid value to insert
      #   into the hash.
      def set(key)
        key = utf8_encode(key)

        return if forbidden_key?(key)
        return unless @raw[key] == nil

        @raw[key] = normalize(yield(key))
      end

      # @return [::Array] a new array populated with the values from this hash.
      # @see #keys
      def values
        @raw.values
      end

      private

      # Converts an object to a Hash using `to_hash`. Raise TypeError if this
      # is not possible.
      #
      # @param obj [#to_hash]
      # @return [Hash]
      # @raise [TypeError] of `obj` doesn't respond to `to_hash`
      def implicit(obj)
        return obj.to_hash if obj.respond_to?(:to_hash)
        raise TypeError, "no implicit conversion of #{obj.class} into Hash"
      end

      # @param merge_method [Symbol] the name of a method used for a nested
      #   merge operation, usually either `:merge` or `:merge!`
      # @param force [Boolean] set to `true` to overwrite keys with divering
      #   value types, or `false` to silently ignore the new value
      # @return [Lambda] a resolver block for deep-merging a hash.
      def deep_merge_resolver(merge_method, force: true)
        resolver = lambda do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            old_val.public_send(merge_method, new_val, force: force, &resolver)
          elsif old_val.is_a?(Array) && new_val.is_a?(Array)
            old_val.public_send(merge_method, new_val)
          else
            force || old_val == nil ? new_val : old_val
          end
        end
      end
    end

    def self.Hash(raw, forbidden_keys: EMPTY_SET)
      Rackstash::Fields::Hash.new(forbidden_keys: forbidden_keys).merge!(raw)
    end
  end
end
