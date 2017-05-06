# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/flow'

module Rackstash
  class Flows
    def initialize(*flows)
      @flows = Concurrent::Array.new

      flows.flatten.each do |flow|
        add(flow)
      end
    end

    def <<(flow)
      flow = Flow.new(flow) unless flow.is_a?(Flow)
      @flows << flow
      self
    end
    alias add <<

    def [](index)
      @flows[index]
    end

    def []=(index, flow)
      flow = Flow.new(flow) unless flow.is_a?(Flow)
      @flows[index] = flow
    end

    def empty?
      @flows.empty?
    end

    def inspect
      id_str = (object_id << 1).to_s(16).rjust(DEFAULT_OBJ_ID_STR_WIDTH, '0')
      "#<#{self.class.name}:0x#{id_str} #{self}>"
    end

    def length
      @flows.length
    end
    alias size length

    def to_ary
      @flows.to_a.compact
    end
    alias to_a to_ary

    def to_s
      @flows.to_s
    end
  end
end
