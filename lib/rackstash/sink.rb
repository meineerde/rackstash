# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  class Sink
    attr_reader :targets

    def initialize(targets)
      @targets = targets.respond_to?(:to_ary) ? targets.to_ary : [targets]
    end

    def flush(buffer)
      @targets.each do |target|
        target.flush(buffer)
      end
    end
  end
end
