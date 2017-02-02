# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'set'

require 'rackstash/fields/abstract_collection'

module Rackstash
  module Fields
    class Tags < AbstractCollection
      def initialize
        @raw = Set.new
      end

      def <<(tag)
        merge!(tag)
      end

      def as_json(*)
        @raw.to_a
      end
      alias :to_ary :as_json
      alias :to_a :as_json

      def clear
        @raw.clear
        self
      end

      def empty?
        @raw.empty?
      end

      def merge(*tags, scope: nil)
        dup.merge!(*tags, scope: scope)
      end

      def merge!(*tags, scope: nil)
        @raw.merge normalize_tags(tags.to_ary)
        self
      end

      def tagged?(tag)
        @raw.include? utf8_encode(tag)
      end

      def to_set
        @raw.dup
      end

      protected

      def normalize_tags(value, scope: nil)
        value = resolve_value(value, scope: scope)

        if value.respond_to?(:to_ary)
          value = value.to_ary.map { |tag| normalize_tags(tag) }
          value.flatten!
          value
        else
          utf8_encode(value).freeze
        end
      end
    end
  end
end

