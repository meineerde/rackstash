# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filters
    # Replace fields in the given event with new values. A new value can be
    # specified as either a fixed value or as a `Proc` (or any other object
    # responding to `call`). In the latter case, the callable object will be
    # called with the event as its argument. It is then expected to return the
    # new value which is set on the key.
    #
    # If a specified field does not exist in the event hash, it will be created
    # with the given (or calculated) value anyway. To ignore a missing field,
    # use the {Update} filter instead.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     filter :replace, {
    #       "sample" => ->(event) { "#{event['source_host']}: #{event['sample']}" }
    #     }
    #   end
    #
    # You should make sure to only set a new object of one of the basic types
    # here, namely `String`, `Integer`, `Float`, `Hash`, `Array`, `nil`, `true`,
    # or `false`.
    class Replace
      # @param spec [Hash<#to_s => #call,Object>] a `Hash` specifying new field
      #   values for the named keys. Values can be given in the form of a fixed
      #   value or a callable object (e.g. a `Proc`) which accepts the event as
      #   its argument and returns the new value.
      def initialize(spec)
        @replace = {}
        Hash(spec).each_pair do |key, value|
          @replace[key.to_s] = value
        end
      end

      # Replace or set fields in the event to a new value.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the fields renamed
      def call(event)
        @replace.each_pair do |key, value|
          value = value.call(event) if value.respond_to?(:call)
          event[key] = value
        end
        event
      end
    end
  end
end
