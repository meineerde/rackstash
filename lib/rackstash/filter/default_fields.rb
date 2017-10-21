# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filter
    # The {DefaultFields} filter allows to define fields which should be added
    # to an event if they aren't already explicitly set.
    #
    # Fields can be given either as a `Hash` or a `Proc` which in turn returns a
    # `Hash` on `call`. The `Hash` can be nested arbitrarily deep.
    #
    # Each `Hash` value can again optionally be a `Proc` which is expected to
    # return a field value on `call`. You can set nested Hashes or Arrays and
    # define nested Procs which in turn are resolved recursively when applying
    # the filter. That way, you can set lazy-evaluated values which are only
    # resolved at the time the filter is applied to a logged event.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     # All three defined filters set the same default fields
    #     filter :default_fields, 'beep' => 'boop'
    #     filter :default_fields, 'beep' => -> { 'boop' }
    #     filter :default_fields, -> { { 'beep' => 'boop' } }
    #   end
    class DefaultFields
      # @param default_fields [Hash<#to_s => Object>, Proc] a `Hash` specifying
      #   default values for the named keys. You can either give a literal
      #   `Hash` object or a `Proc` which returns such a `Hash`.
      def initialize(default_fields)
        @default_fields = default_fields
      end

      # Add the defined `default_fields` to the event hash, retaining all
      # existing values.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the fields renamed
      def call(event)
        resolver = lambda do |key, old_val, new_val|
          if old_val.nil?
            new_val
          elsif old_val.is_a?(Hash) && new_val.is_a?(Hash)
            old_val.merge(new_val, &resolver)
          elsif old_val.is_a?(Array) && new_val.is_a?(Array)
            old_val | new_val
          else
            old_val
          end
        end

        fields = Rackstash::Fields::Hash(@default_fields).to_h
        event.merge!(fields, &resolver)
      end
    end
  end
end
