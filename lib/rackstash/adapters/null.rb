# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/adapters/adapter'
require 'rackstash/encoders/raw'

module Rackstash
  module Adapters
    # This adapter swallows all logs sent to it without writing them anywhere.
    #
    # It is probably not very useful for production use but can be used to test
    # the {Flow} pipeline.
    class Null < Adapter
      register_for NilClass

      # Create a new black hole adapter. Any logs written to it will be
      # swallowed and not written anywhere.
      def initialize(*)
      end

      # By default, we use a {Rackstash::Encoders::Raw} encoder to encode the
      # events. Since we are ignoreing them anyway, there is no need for fancy
      # formatting here.
      #
      # @return [Rackstash::Encoders::Raw] a new Raw encoder
      def default_encoder
        Rackstash::Encoders::Raw.new
      end

      # Swallow a log event. It is not written anywhere.
      #
      # @param log [Object] the encoded log event
      # @return [nil]
      def write_single(log)
        nil
      end
    end
  end
end
