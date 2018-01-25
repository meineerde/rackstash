# frozen_string_literal: true
#
# Copyright 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'set'

require 'rackstash/filter'
require 'rackstash/helpers/utf8'

module Rackstash
  module Filter
    # Only keep named fields on the top-level of the given event. All key-value
    # pairs in the given event with a key matching any of field matchers given
    # in {#initialize} will be kept. Conversely, all fields matching none of the
    # field matchers will be removed from the event.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     filter :select,
    #       'message',
    #       '@timestamp',
    #       'tags',
    #       /\Ahttp_/,                 # keep all fields beginning with "http_"
    #       ->(key) { key.length < 5 } # keep all fields with short keys
    #   end
    #
    # With the example above, we are keeping the default fields, as well as any
    # keys starting with `"http_"` or have short names. Here, we are thus
    # retaining e.g. fields named `"http_path"` or `"uuid"`. Fields like
    # `"user_name"`, `"webserver"`, or `"robot_arm"` will be removed from the
    # event however since they don't match any of the configured matchers.
    class Select
      include Rackstash::Helpers::UTF8

      # @param field_matchers [Array<String,Symbol,Regexp,Proc,#===>] the fields
      #   to keep in the event. You can specify this in a varienty of ways,
      #   usually as a `String` or `Symbol` (which is compared to the key) or
      #   as a `Regexp`, `Proc` (which gets passed the key to check for
      #   inclusion) or any other object responding to the `===` method. You can
      #   also provide a block which is used as an additional `Proc` matcher in
      #   this case.
      def initialize(*field_matchers, &block)
        keys, matchers = field_matchers.flatten.partition { |field|
          field.is_a?(String) || field.is_a?(Symbol)
        }

        @keys = Set[*keys.map! { |key| utf8_encode(key) }]
        @matchers = matchers
        @matchers << block if block_given?
      end

      # Keep only key-value pairs in the given event where the key matches any
      # of the configured field names.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with only matching fields retained and
      #   non-matching fields removed
      def call(event)
        event.keep_if { |key, _value|
          @keys.include?(key) || @matchers.any? { |matcher| matcher === key }
        }
        event
      end
    end

    register Select, :select
  end
end
