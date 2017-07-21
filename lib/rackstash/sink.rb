# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/flows'

module Rackstash
  class Sink
    # @return [Flows] the defined {Flows} which are responsible for
    #   transforming, encoding, and persisting an event Hash.
    attr_reader :flows

    # @param flows [Array<Flow, Object>, Flow, Adapters::Adapter, Object]
    #   an array of {Flow}s or a single {Flow}, respectivly object which can be
    #   used as a {Flow}'s adapter. See {Flow#initialize}.
    def initialize(flows)
      @flows = Rackstash::Flows.new(flows)

      @default_fields = {}
      @default_tags = []
    end

    # @return [Hash, Proc] the default fields which get deep merged into the
    #   created event Hash when flushing a {Buffer}.
    def default_fields
      @default_fields
    end

    # The default fields get deep merged into the created event hash when
    # flushing a {Buffer}. They can be given either as a `Hash` or a `Proc`
    # which in turn returns a `Hash` on `call`. The `Hash` can be nested
    # arbitrarily deep.
    #
    # Each Hash value can again optionally be a Proc which in turn is expected
    # to return a field value on `call`. You can set nested Hashes or Arrays and
    # define nested Procs which in turn are called recursively when flushing a
    # {Buffer}. That way, you can set lazy-evaluated values.
    #
    # @example
    #   # All three values set the same default fields
    #   sink.default_fields = {'beep' => 'boop'}
    #   sink.default_fields = -> { { 'beep' => 'boop' } }
    #   sink.default_fields = { 'beep' => -> { 'boop' } }
    #
    # @param fields [#to_hash, Proc] The default fields to be merged into the
    #   event Hash when flushing a {Buffer}.
    # @raise [TypeError] if `fields` is neither a Proc nor can be converted to a
    #   Hash
    # @return [Hash, Proc] the given `fields`
    def default_fields=(fields)
      fields = fields.to_hash if fields.respond_to?(:to_hash)
      unless fields.is_a?(Hash) || fields.is_a?(Proc)
        raise TypeError, 'default_fields must be a Hash or Proc'
      end

      @default_fields = fields
    end

    # @return [Array<#to_s, Proc>, Proc] the default tags are added to the
    #   `"@tags"` field of the created event Hash when flushing a {Buffer}. They
    #   can be given either as an `Array` of `String`s or a `Proc` which in turn
    #   returns an `Array` of `String`s on `call`.
    def default_tags
      @default_tags
    end

    # The default tags are added to the `"@tags"` field of the created event
    # Hash when flushing a {Buffer}. They can be given either as an `Array` of
    # `String`s or a `Proc` which in turn returns an `Array` of `String`s on
    # `call`.
    #
    # Each value of the Array can again optionally be a Proc which in turn is
    # expected to return a String on `call`. All the (potentially nested) procs
    # are called recursively when flushing a {Buffer}. That way, you can set
    # lazy-evaluated values.
    #
    # @example
    #   # All three values set the same default tags
    #   sink.default_tags = ['important', 'request']
    #   sink.default_tags = -> { ['important', 'request'] }
    #   sink.default_tags = [ 'important', -> { 'request' } }
    #
    # @param tags [#to_ary, Proc] The default tags to be merged into the event
    #   Hash's `"@tags"` field when flushing a {Buffer}
    # @raise [TypeError] if `tags` is neither a Proc nor can be converted to an
    #   Array
    # @return [Array, Proc] the given `tags`
    def default_tags=(tags)
      tags = tags.to_ary if tags.respond_to?(:to_ary)
      unless tags.is_a?(Array) || tags.is_a?(Proc)
        raise TypeError, 'default_tags must be an Array or Proc'
      end

      @default_tags = tags
    end

    # Close the log adapter for each configured {Flow}. This might be a no-op
    # depending on each flow's adapter.
    #
    # @return [nil]
    def close
      @flows.each(&:close)
      nil
    end

    # Close and re-open the log adapter for each configured {Flow}. This might
    # be a no-op depending on each flow's adapter.
    #
    # @return [nil]
    def reopen
      @flows.each(&:reopen)
      nil
    end

    # Create an event hash from the given `buffer` and write it to each of the
    # defined {#flows}.
    #
    # First, we transform the given `buffer` to an event hash:
    #
    # * We deep-merge the {#default_fields} into the `buffer`'s fields and use
    #   it as the basis the the event hash. Existing fields on the `buffer` will
    #   always have precedence here.
    # * We add the {#default_tags} to the `buffer`'s tags and add them as a raw
    #   array of strings to the `event['tags']` field.
    # * We add the `buffer`'s array of messages to `event['message']`. This
    #   field now contains an array of {Message} objects.
    # * We add the `buffer`'s timestamp to the `event['@timestamp]` field as an
    #   ISO 8601 formatted string. The timestamp is always in UTC.
    # * We add the version of the logstash event format as
    #   `event[@version] = 1`.
    #
    # The typical event emitted here looks like this:
    #
    #     {
    #       "beep" => "boop",
    #       "foo" => ["bar", "baz"],
    #       "tags" => ["request", "controller#action"],
    #       "message" => [
    #         #<Rackstash::Message:0x007f908b4414c0 ...>,
    #         #<Rackstash::Message:0x007f908d14aee0 ...>
    #       ],
    #       "@timestamp" => "2016-10-17T13:37:42.000Z",
    #       "@version" => "1"
    #     }
    #
    # The resulting event hash is written to each defined {Flow}. Since a flow
    # usually changes the event hash with its filters and encoder, we create a
    # fresh copy of the hash for each flow.
    #
    # @param buffer [Buffer] The buffer cotnaining the data to write to the
    #   {#flows}.
    # @return [Buffer] the given `buffer`
    def write(buffer)
      event = event_from_buffer(buffer)

      # Memoize the current list of flows for the rest of the method to make
      # sure it doesn't change while we work with it.
      flows = @flows.to_a
      flows_size = flows.size

      flows.each_with_index do |flow, index|
        # If we have more than one flow, we provide a fresh copy of the event
        # to each flow. The flow's filter and codec can then mutate the event
        # however it pleases without affecting later flows. We don't need to
        # duplicate the event for the last flow since it won't be re-used
        # after that anymore.
        current_event = (index == flows_size - 1) ? event : deep_dup_event(event)

        flow.write(current_event)
      end

      buffer
    end

    private

    # Create a raw event hash from a Buffer.
    #
    # Note that the resulting hash still contains an Array of {Message}s in the
    # `"message"` field. This allows flow {Filters} to reject or adapt some
    # messages based on their original attributes, e.g., their severity or
    # timestamp.
    #
    # @see Flow#write
    #
    # @param buffer [Buffer] a buffer instance
    # @return [Hash] the event expected by the event filters.
    def event_from_buffer(buffer)
      event = buffer.fields.deep_merge(@default_fields, force: false).to_h
      event[FIELD_TAGS] = buffer.tags.merge(@default_tags).to_a
      event[FIELD_MESSAGE] = buffer.messages
      event[FIELD_TIMESTAMP] = buffer.timestamp
      event[FIELD_VERSION] = '1'.freeze

      event
    end

    # Create a deep duplicate of an event hash. It is assumed that the input
    # event follows the normalized structure as generated by
    # {Fields::Hash#to_h}.
    #
    # @param obj [Object] an object to duplicate. When initially called, this is
    #   expected to be an event hash
    # @return [Object] a deep copy of the given `obj` if it was an `Array` or
    #   `Hash`, the original `obj` otherwise.
    def deep_dup_event(obj)
      case obj
      when Hash
        hash = obj.dup
        obj.each_pair do |key, value|
          # {Rackstash::Fields::Hash} already guarantees that keys are always
          # frozen Strings. We don't need to dup them.
          hash[key] = deep_dup_event(value)
        end
      when Array
        obj.map { |value| deep_dup_event(value) }
      else
        # All leaf-values in the event are either frozen or not freezable /
        # dupable. They can be used as is. See {AbstractCollection#normalize}
        obj
      end
    end
  end
end
