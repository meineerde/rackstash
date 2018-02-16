# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'concurrent'

require 'rackstash/flow'

module Rackstash
  # The `Flows` class provides a thread-safe list of {Flow} objects which are
  # used to write a single log event of a {Buffer} to multiple flows. Each
  # {Logger} object has an associated Flows object to define the logger's flows.
  class Flows
    include ::Enumerable

    # @param flows [::Array<Flow, Adapter::Adapter, Object>] the {Flow} objects
    #   which should be part of the list. If any of the arguments is not a
    #   {Flow} already, we assume it is an adapter and create a new {Flow} for
    #   it.
    def initialize(*flows)
      @flows = Concurrent::Array.new

      flows.each do |flow|
        add(flow)
      end
    end

    # Add a new flow at the end of the list.
    #
    # @param flow [Flow, Adapter::Adapter, Object] The flow to add to the end
    #   of the list. If the argument is not a {Flow}, we assume it is an adapter
    #   and create a new {Flow} with it.
    # @return [self]
    def <<(flow)
      flow = Flow.new(flow) unless flow.is_a?(Flow)
      @flows << flow
      self
    end
    alias add <<

    # Retrieve an existing flow from a given `index`
    #
    # @param index [Integer] the index in the list where we fetch the flow
    # @return [Flow, nil] the flow at `index` or `nil` if no flow could be found
    def [](index)
      @flows[index]
    end

    # Set a flow at a given index. If the argument is not a {Flow}, we assume it
    # is an adapter and create a new {Flow} for it.
    #
    # @param index [Integer] the index in the list where we set the flow
    # @param flow [Flow, Adapter::Adapter, Object] The flow to add at `index`.
    #   If the argument is not a {Flow}, we assume it is an adapter and create
    #   a new {Flow} with it.
    # @return [void]
    def []=(index, flow)
      flow = Flow.new(flow) unless flow.is_a?(Flow)
      @flows[index] = flow
      flow
    end

    # Calls the given block once for each flow in `self`, passing that flow as
    # a parameter. We only yield non-nil elements. Concurrent changes to `self`
    # do not affect the running enumeration.
    #
    # An `Enumerator` is returned if no block is given.
    #
    # @yield [flow] calls the given block once for each flow
    # @yieldparam flow [Flow] the yielded flow
    # @return [Enumerator, self] `self` if a block was given or an `Enumerator`
    #   if no block was given.
    def each
      return enum_for(__method__) unless block_given?
      to_a.each do |flow|
        yield flow
      end
      self
    end

    # @return [Boolean] `true` if `self` contains no elements, `false` otherwise
    def empty?
      @flows.empty?
    end

    # @overload first
    #   @return [Flow, nil] the first flow. If the list is empty, `nil` is
    #     returned.
    #
    # @overload first(n)
    #   @param n [Integer] the number of flows to return
    #   @return [Array<Flow>] the first `n` flows. If the list is empty, an
    #     empty array is returned.
    #
    # @return [Flow, Array<Flow>, nil]
    # @see #last #last for the opposite effect.
    def first(n = UNDEFINED)
      if UNDEFINED.equal? n
        @flows.first
      else
        @flows.first(n)
      end
    end

    # Prevents further modifications to the flows list. A `RuntimeError` will be
    # raised if you attempt to add, delete, or overwrite flows in the list.
    # There is no way to unfreeze a frozen object.
    #
    # @return [self]
    def freeze
      @flows.freeze
      super
    end

    # @return [String] a string representation of `self`
    def inspect
      id_str = Object.instance_method(:to_s).bind(self).call[2..-2]
      "#<#{id_str} #{self}>"
    end

    # @overload last
    #   @return [Flow, nil] the last flow. If the list is empty, `nil` is
    #     returned.
    #
    # @overload last(n)
    #   @param n [Integer] the number of flows to return
    #   @return [Array<Flow>] the last `n` flows. If the list is empty, an empty
    #     array is returned.
    #
    # @return [Flow, Array<Flow>, nil]
    # @see #first #first for the opposite effect.
    def last(n = UNDEFINED)
      if UNDEFINED.equal? n
        @flows.last
      else
        @flows.last(n)
      end
    end

    # @return [Integer] the number of elements in `self`. May be zero.
    def length
      @flows.length
    end
    alias size length

    # Close the log adapter for each configured {Flow}. This might be a no-op
    # depending on each flow's adapter.
    #
    # @return [nil]
    def close
      each(&:close)
      nil
    end

    # Close and re-open the log adapter for each configured {Flow}. This might
    # be a no-op depending on each flow's adapter.
    #
    # @return [nil]
    def reopen
      each(&:reopen)
      nil
    end

    # Write an event `Hash` to each of the defined flows. The event is usually
    # created from {Buffer#to_event}.
    #
    # We write a fresh deep-copy of the event hash to each defined {Flow}.
    # This allows each flow to alter the event in any way without affecting the
    # others.
    #
    # @param event [Hash] an event `Hash`
    # @return [Hash] the given `event`
    def write(event)
      # Memoize the current list of flows for the rest of the method to make
      # sure it doesn't change while we work with it.
      flows = to_a
      flows_size = flows.size

      event = event.to_h
      flows.each_with_index do |flow, index|
        # If we have more than one flow, we provide a fresh copy of the event
        # to each flow. The flow's filters and encoder can then mutate the event
        # however it pleases without affecting later flows. We don't need to
        # duplicate the event for the last flow since it won't be re-used
        # after that anymore.
        current_event = (index == flows_size - 1) ? event : deep_dup_event(event)
        flow.write(current_event)
      end

      event
    end

    # @return [Array<Flow>] an array of all flow elements without any `nil`
    #   values
    def to_ary
      @flows.to_a.tap(&:compact!)
    end
    alias to_a to_ary

    # @return [String] an Array-compatible string representation of `self`
    def to_s
      @flows.to_s
    end

    protected

    attr_reader :flows

    private

    def initialize_copy(other)
      @flows = other.flows.dup
      super
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
