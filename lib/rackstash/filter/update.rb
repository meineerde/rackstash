# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filter
    # Update fields in the given event with new values. A new value can be
    # specified as either a fixed value or as a `Proc` (or any other object
    # responding to `call`). In the latter case, the callable object will be
    # called with the event as its argument. It is then expected to return the
    # new value which is set on the key.
    #
    # If a specified field does not exist in the event hash yet, it will not be
    # set and the respective proc will not be called. To set the field with the
    # specified value anyway, use the {Replace} filter instead.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     filter :update, {
    #       "sample" => ->(event) { event['key'] }
    #     }
    #   end
    #
    # You should make sure to only set a new object of one of the basic types
    # here, namely `String`, `Integer`, `Float`, `Hash`, `Array`, `nil`, `true`,
    # or `false`.
    class Update
      # @param spec [Hash<#to_s => #call,Object>] a `Hash` specifying new field
      #   values for the named keys. Values can be given in the form of a fixed
      #   value or a callable object (e.g. a `Proc`) which accepts the event as
      #   its argument and returns the new value.
      def initialize(spec)
        @update = {}
        Hash(spec).each_pair do |key, value|
          @update[key.to_s] = value
        end
      end

      # Update existing field fields in the event with a new value.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the fields renamed
      def call(event)
        @update.each_pair do |key, value|
          next unless event.key?(key)

          value = value.call(event) if value.respond_to?(:call)
          event[key] = value
        end
        event
      end
    end
  end
end
