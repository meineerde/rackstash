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

      # @param field_name [#to_s] the key name. We will always use it as a
      #   String.
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
      #   will be normalized as a string.
      # @param value [#call, Object] any value which can be serialized to JSON.
      #   The value will be normalized on insert
      #
      # @raise [ArgumentError] if you attempt to set one of the forbidden keys.
      # @return void
      def []=(key, value)
        key = utf8_encode(key)
        raise ArgumentError, "Forbidden field #{key}" if forbidden_key?(key)

        @raw[key] = normalize(value)
      end
      alias :store :[]=

      def as_json(*)
        @raw.each_with_object({}) do |(key, value), memo|
          value = value.as_json if value.is_a?(AbstractCollection)
          memo[key] = value
        end
      end
      alias :to_hash :as_json
      alias :to_h :as_json

      def clear
        @raw.clear
        self
      end

      def empty?
        @raw.empty?
      end

      def keys
        @raw.keys
      end

      def merge(hash, force: true, scope: nil, &block)
        dup.merge!(hash, force: force, scope: scope, &block)
      end

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

      def forbidden_key?(key)
        @forbidden_keys.include?(key)
      end

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
      Hash.new(forbidden_keys: forbidden_keys).merge!(raw)
    end
  end
end
