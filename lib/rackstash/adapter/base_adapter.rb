# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'cgi'
require 'uri'

require 'rackstash/adapter'
require 'rackstash/encoder/json'

module Rackstash
  module Adapter
    # The Adapter wraps a raw external log device like a file, an IO object like
    # `STDOUT`, the system's syslog or even the connection to a TCP server with
    # a common interface. At the end of a {Flow}, it is responsible to finally
    # store the filtered and encoded log event.
    #
    # Each concrete adapter can register itself so that it can be used to wrap
    # any compatible log device with {Rackstash::Adapter.[]}.
    #
    # @abstract Subclasses need to override at least {#write_single} to
    #   implement a concrete log adapter.
    class BaseAdapter
      # Register the current class as an adapter for the provided matchers.
      #
      # This is a convenience method intended to be used by sub-classes of this
      # abstract parent class to register themselves as adapters.
      #
      # @param matchers [Array<String, Symbol, #===>] a list of specifications
      #   for log devices the current adapter can forward logs to.
      # @return [self]
      # @see Adapter.register
      def self.register_for(*matchers)
        Rackstash::Adapter.register(self, *matchers)
      end

      class << self
        private

        def parse_uri_options(uri)
          options = {}
          (uri.query || EMPTY_STRING).split(/[&;] */n).each do |option|
            next if option.empty?
            k, v = option.split('='.freeze, 2).map! { |s| CGI.unescape(s) }
            k = k.to_sym

            if cur = options[k]
              if cur.class == Array
                options[k] << v
              else
                options[k] = [cur, v]
              end
            else
              options[k] = v
            end
          end
          options
        end
      end

      # Create a new adapter instance.
      #
      # Usually, this method is overwritten by child classes to accept a
      # suitable log device which will be used to write log lines to. When
      # registering the adapter class, {Rackstash::Adapter.[]} will call
      # {initialize} with a single argument: the log device.
      def initialize(*)
      end

      # By default, we use a {Rackstash::Encoder::JSON} encoder to encode the
      # events for the adapter.
      #
      # If no explicit encoder is defined in a {Flow}, this encoder will be used
      # there.
      #
      # @return [Rackstash::Encoder::JSON] a new JSON encoder
      def default_encoder
        Rackstash::Encoder::JSON.new
      end

      # Close the underlying log device if supported by it.
      #
      # This method needs to be overwritten in child classes. By default, this
      # method does nothing.
      #
      # @return [void]
      def close
      end

      # Close and re-open the underlying log device if supported by it.
      #
      # This method needs to be overwritten in child classes. By default, this
      # method does nothing.
      #
      # @return [void]
      def reopen
      end

      # Write a log line to the log device. This method is called by the flow
      # with a formatted log event.
      #
      # @param log [Object] the encoded log event
      # @return [nil]
      def write(log)
        write_single(log)
        nil
      end

      # Write a single log line to the log device.
      #
      # This method needs to be overwritten in adapter sub classes to write the
      # encoded log event to the adapter's device. When not overwritten, this
      # method raises a {NotImplementedHereError}.
      #
      # @param log [Object] the encoded log event
      # @return [void]
      # @raise NotImplementedHereError
      def write_single(log)
        raise NotImplementedHereError, 'write_single needs to be implemented ' \
          'in the actual adapter subclass'
      end

      private

      # Helper method to ensure that a log line passed to {#write} is either a
      # String that ends in a separator character (`"\n"` by default) or is an
      # empty String.
      #
      # @param line [#to_s] a log line
      # @param sep [String] a separator character which is added to the end of
      #   the `line` if not already present there
      # @return [String] `line` with the separator character appended if
      #   necessary
      def normalize_line(line, sep = "\n".freeze)
        line = line.to_s
        return line if line.empty? || line.end_with?(sep)

        line + sep
      end
    end
  end
end
