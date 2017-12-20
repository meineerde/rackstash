# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/filter'

module Rackstash
  module Filter
    # Skip the further processing of the event if the provided condition is
    # truethy. In that case, the event will be dropped and not be written to the
    # log adapter.
    #
    # This filter is a basic example of how you can write filters which abort
    # further processing of an event. You can write your own filters which
    # provide similar (but probably more useful) behavior.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     # Drop the event if it has the 'debug' tag
    #     filter :drop_if, ->(event) { event['tags'].include?('debug') }
    #   end
    class DropIf
      # @param drop_if [#call] a callable object (e.g. a `Proc`) which returns a
      #  truethy or falsey value on `call` with an `event` hash. If it returns
      #  something truethy, we abort any further processing of the event. If the
      #  `drop_if` filter is not given, we expect a block to be provided which
      #  is used instead.
      def initialize(drop_if = nil, &block)
        if drop_if.respond_to?(:call)
          @drop_if = drop_if
        elsif block_given?
          @drop_if = block
        else
          raise ArgumentError, 'must provide a condition when to drop the event'
        end
      end

      # Run the filter against the passed `event` hash.
      #
      # We will call the `drop_if` object with the passed event. If the return
      # value is truethy, we abort any further processing of the event. This
      # filter does not change the `event` hash in any way on its own.
      #
      # @param event [Hash] an event hash
      # @return [Hash, false] the given `event` or `false` if the `drop_if`
      #   condition was evaluated
      def call(event)
        return false if @drop_if.call(event)
        event
      end
    end

    register DropIf, :drop_if
  end
end
