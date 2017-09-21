# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'concurrent'

require 'rackstash/flow'

module Rackstash
  # The `Flows` class provides a thread-safe list of {Flow} objects which are
  # used to dispatch a single log events to multiple flows from the {Sink}.
  class Flows
    # @param flows [::Array<Flow, Adapters::Adapter, Object>] the {Flow} objects
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
    # @param flow [Flow, Adapters::Adapter, Object] The flow to add to the end
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
    # @param flow [Flow, Adapters::Adapter, Object] The flow to add at `index`.
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
  end
end
