# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filters
    # The {DefaultTags} filter allows to define tags which should be added
    # to an event if they aren't already explicitly set there. All existing tags
    # on the event are retained.
    #
    # The default tags are added to the `"tags"` field of the event `Hash`. They
    # can be given either as an `Array` of `String`s or a `Proc` which in turn
    # returns an `Array` of `String`s on `call`.
    #
    # Each value of the Array can again optionally be a Proc which in turn is
    # expected to return a String on `call`. All the (potentially nested) procs
    # are called recursively when applying the filter. That way, you can set
    # lazy-evaluated values which are only resolved at the time the filter is
    # applied to a logged event.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     # All three defined filters set the same default tags
    #     filter :default_tags, ['important', 'request']
    #     filter :default_tags, -> { ['important', 'request'] }
    #     filter :default_tags, ['important', -> { 'request' }]
    #   end
    class DefaultTags
      # @param default_tags [Array<#to_s>, Set<#to_s>, Proc] an `Array`
      #   specifying default tags for each event. You can either give a literal
      #   `Array` containing Strings or a `Proc` which returns such an `Array`.
      def initialize(*default_tags)
        @default_tags = default_tags
      end

      # Add the defined `default_tags` to the event hash, retaining all
      # existing tags. The `"tags"` field on the event will be normalized to a
      # plain `Array` containing only `String`s.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the fields renamed
      def call(event)
        tags = Rackstash::Fields::Tags(event[FIELD_TAGS])
        tags.merge!(@default_tags)

        event[FIELD_TAGS] = tags.to_a
        event
      end
    end
  end
end
