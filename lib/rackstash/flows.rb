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
    # @param flows ::Array<Flow, Adapter> the {Flow} objects which should be
    #   part of the list. If any of the arguments is not a {Flow} already, we
    #   assume it is an adapter and create a new {Flow} for it.
    def initialize(*flows)
      @flows = Concurrent::Array.new

      flows.flatten.each do |flow|
        add(flow)
      end
    end

    # Add a new flow at the end of the list.
    #
    # @param flow [Flow, Adapter] The flow to add to the end of the list. If
    #   the argument is not a {Flow}, we assume it is an adapter and create a
    #   new {Flow} for it.
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
    # @param value [Flow, Adapter] The flow to add to the end at `index`. If the
    #   argument is not a {Flow}, we assume it is an adapter and create a new
    #   {Flow} for it.
    # @return [void]
    def []=(index, flow)
      flow = Flow.new(flow) unless flow.is_a?(Flow)
      @flows[index] = flow
    end

    # @return [Boolean] `true` if `self` contains no elements, `false` otherwise
    def empty?
      @flows.empty?
    end

    # @return [String] a string representation of `self`
    def inspect
      id_str = (object_id << 1).to_s(16).rjust(DEFAULT_OBJ_ID_STR_WIDTH, '0')
      "#<#{self.class.name}:0x#{id_str} #{self}>"
    end

    # @return [Integer] the number of elements in `self`. May be zero.
    def length
      @flows.length
    end
    alias size length

    # @return [Array<Flow>] an array of all flow elementswithout any `nil`
    #   values
    def to_ary
      @flows.to_a.compact
    end
    alias to_a to_ary

    # @return [String] an Array-compatible string representation of `self`
    def to_s
      @flows.to_s
    end
  end
end
