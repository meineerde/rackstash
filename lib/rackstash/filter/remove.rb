# frozen_string_literal: true
#
# Copyright 2018-2020 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/filter'
require 'rackstash/utils'

module Rackstash
  module Filter
    # Delete all key-value pair from the given event where the key matches any
    # of the field matchers. All other key-value pairs will be retained.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     filter :remove, 'api_key', 'runtime'
    #     #      ^^^^^^^ You can also use :delete here
    #   end
    class Remove
      include Rackstash::Utils

      # @param field_matchers [Array<String,Symbol,Regexp,Proc,#===>] the fields
      #   to remove from the event. You can specify this in a varienty of ways,
      #   usually as a `String` or `Symbol` (which is compared to the key) or
      #   as a `Regexp`, `Proc` (which gets passed the key to check for
      #   inclusion) or any other object responding to the `===` method. You can
      #   also provide a block which is used as an additional `Proc` matcher in
      #   this case.
      def initialize(*field_matchers)
        keys, matchers = field_matchers.flatten.partition { |field|
          field.is_a?(String) || field.is_a?(Symbol)
        }

        @keys = Set[*keys.map! { |key| utf8(key) }]
        @matchers = matchers
        @matchers << block if block_given?
      end

      # Remove all key-value pairs in the given event where the key matches any
      # of the configured field names.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with all matching fields removed
      def call(event)
        event.delete_if { |key, _value|
          @keys.include?(key) || @matchers.any? { |matcher| matcher === key }
        }
        event
      end
    end

    register Remove, :remove, :delete
  end
end
