# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/filter'
require 'rackstash/helpers/utf8'

module Rackstash
  module Filter
    # Rename one or more fields in the given event.
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     # Renames the "HOST_OR_IP" field to "client_ip"
    #     filter :rename, "HOST_OR_IP" => "client_ip"
    #   end
    class Rename
      include Rackstash::Helpers::UTF8

      # @param spec [Hash<#to_s => #to_s>] a `Hash` specifying how fields should
      #   be renamed, with the existing field name as a hash key and the new
      #   field name as the respective value.
      def initialize(spec)
        @rename = {}
        Hash(spec).each_pair do |key, value|
          @rename[utf8_encode(key)] = utf8_encode(value)
        end
      end

      # Rename fields in the event to a new name. If a field was not found,
      # it will be ignored.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the fields renamed
      def call(event)
        @rename.each_pair do |old_key, new_key|
          next unless event.key?(old_key)
          event[new_key] = event.delete(old_key)
        end
        event
      end
    end

    register Rename, :rename
  end
end
