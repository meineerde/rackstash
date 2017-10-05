# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/adapters/adapter'
require 'rackstash/encoders/hash'

module Rackstash
  module Adapters
    # This adapter calls a user-provided "callable", i.e., a `Proc` or block for
    # each written log line. This allows users to custom handle the logs without
    # having to write a full custom adapter class.
    #
    # You can pass the callable as a block to {#initialize} or as a Proc or any
    # other object responding to `call`. For each written log, we call the block
    # once.
    #
    # Note that we do not ensure that the calls are sequentially. If multiple
    # threads are concurrently writing logs to the logger, the calable might be
    # called concurrently from multiple threads too.
    #
    # To create an adapter instance, you can use this example:
    #
    #     Rackstash::Adapters::Callable.new do |log|
    #       # handle the log as required
    #     end
    class Callable < Adapter
      register_for ::Proc, :call

      # Create a new Callable adapter by wrapping a proc. You can pass the proc
      # either as the firat parameter to {#initialize} or as a block which is
      # then transformed into a proc internally.
      #
      # @param callable [Proc, #call] a callable object, usually a proc or
      #   lambda
      def initialize(callable = nil, &block)
        if callable.respond_to?(:call)
          @callable = callable
        elsif block_given?
          @callable = block
        else
          raise TypeError, "#{callable.inspect} does not appear to be callable"
        end
      end

      # By default, we use an {Rackstash::Encoders::Hash} to encode the events.
      # This ensures that all of the data in the logged event is passed through
      # to the callable by default.
      #
      # You can define a custom encoder in the responsible {Flow}.
      #
      # @return [Rackstash::Encoders::Hash] a new Hash encoder
      def default_encoder
        Rackstash::Encoders::Hash.new
      end

      # Write a single log line by calling the defined `callable` given in
      # {#initialize}.
      #
      # @param log [Object] the encoded log event
      # @return [nil]
      def write_single(log)
        @callable.call(log)
        nil
      end
    end
  end
end
