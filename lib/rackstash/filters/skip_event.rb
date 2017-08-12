# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filters
    # Skip the further processing of the event of the condition is `true`.
    #
    # This filter is a basic example of how you can write filters which abort
    # further processing of an event. You can write your own filters which
    # provide similar (but probably more useful) behavior.
    class SkipEvent
      # @param skip_if [#call] a callable object (e.g. a `Proc`) which returns a
      #  truethy or falsey value on `call` with an `event` hash. If it returns
      #  something truethy, we abort any further processing of the event. If the
      #  `skip_if` filter is not given, we expect a block to be provided which
      #  is used instead.
      def initialize(skip_if = nil, &block)
        if skip_if.respond_to?(:call)
          @skip_if = skip_if
        elsif block_given?
          @skip_if = block
        else
          raise TypeError, 'must provide a skip condition'
        end
      end

      # Run the filter against the passed `event` hash.
      #
      # We fill call the `skip_if` object with the passed event. If the return
      # value is truethy, we abort any further processing of the event. This
      # filter does not change the `event` hash in any way on its own.
      #
      # @param event [Hash] an event hash
      # @return [Hash, false] the given `event` or `false` if the `skip_if`
      #   condition was evaluated
      def call(event)
        return false if @skip_if.call(event)
        event
      end
    end
  end
end
