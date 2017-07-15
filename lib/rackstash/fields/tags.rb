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
        @raw = Concurrent::Hash.new
      end

      def <<(tag)
        tag = resolve_value(tag)
        tag = utf8_encode(tag)
        @raw[tag] = true unless tag.empty?
        self
      end

      def as_json(*)
        @raw.keys
      end
      alias to_ary as_json
      alias to_a as_json

      def clear
        @raw.clear
        self
      end

      def empty?
        @raw.empty?
      end

      def merge(tags, scope: nil)
        dup.merge!(tags, scope: scope)
      end

      def merge!(tags, scope: nil)
        tags = normalize_tags(tags, scope: scope)
        Array(tags).each do |tag|
          @raw[tag] = true unless tag.empty?
        end
        self
      end

      def tagged?(tag)
        @raw.key? utf8_encode(tag)
      end

      def to_set
        Set.new to_a
      end

      protected

      def normalize_tags(value, scope: nil)
        value = resolve_value(value, scope: scope)

        if value.is_a?(self.class)
          value.to_a
        elsif value.is_a?(Set)
          value = value.map { |tag| normalize_tags(tag, scope: scope) }
          value.flatten!
          value
        elsif value.respond_to?(:to_ary)
          value = value.to_ary.map { |tag| normalize_tags(tag, scope: scope) }
          value.flatten!
          value
        else
          utf8_encode(value).strip
        end
      end
    end

    # @param tags [Set, ::Array, Array #to_a]
    # @return [Tags]
    def self.Tags(tags)
      Rackstash::Fields::Tags.new.merge!(tags)
    end
  end
end
