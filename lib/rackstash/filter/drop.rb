# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/filter'

module Rackstash
  module Filter
    # This filter skips a certain percentage of events passed through it. It
    # does not change the `event` hash in any way on its own.
    #
    # You can select the events to be filtered be using an `:if` or `:unless`
    # guard when adding the filter to the {FilterChain}.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     # Drop half of all the events which have a 'debug' tag
    #     filter :drop, percent: 50, if: ->(event) { event['tags'].include?('debug') }
    #   end
    class Drop
      # @return [Integer] the percentage of events dropped by this filter
      attr_reader :percent

      # @param percent [Integer] the percentage of events passed through this
      #   filter which are dropped. Can be an integer between 0 and 100
      #   (inclusive).
      def initialize(percent: 100)
        @percent = Integer(percent)
        unless percent.between?(0, 100)
          raise ArgumentError, "percent must be an Integer between 0 and 100"
        end

        @rand = Random.new
      end

      # Run the filter against the passed `event` hash.
      #
      # We drop a defined percentage of log events passing through the filter.
      # If an `event` is selected to be dropped, we return `false`, else we just
      # return the passed event.
      #
      # @param event [Hash] an event hash
      # @return [Hash, false] the given `event` or `false` if the event is
      #   dropped
      def call(event)
        return false if drop?
        event
      end

      private

      # @return [Bool] `true` is the event should be dropped based on the
      #   defined drop percentage, `false` otherwise.
      def drop?
        return true if @percent == 100
        return true if random_percentage < @percent

        false
      end

      # @return [Integer] a random number between 0 and 99 (inclusive).
      def random_percentage
        @rand.rand(100)
      end
    end

    register Drop, :drop
  end
end
