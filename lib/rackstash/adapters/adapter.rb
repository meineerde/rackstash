# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/adapters'
require 'rackstash/encoders/json'

module Rackstash
  module Adapters
    # The Adapter wraps a raw external log device like a file, an IO object like
    # `STDOUT`, the system's syslog or even the connection to a TCP server with
    # a common interface. At the end of a {Flow}, it is responsible to finally
    # store the filtered and encoded log event.
    #
    # Each concrete adapter can register itself so that it can be used to wrap
    # any compatible log device with {Rackstash::Adapters.[]}.
    #
    # @abstract Subclasses need to override at least {#write_single} to
    #   implement a concrete log adapter.
    class Adapter
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
        Rackstash::Adapters.register(self, *matchers)
      end

      # Create a new adapter instance.
      #
      # Usually, this method is overwritten by child classes to accept a
      # suitable log device which will be used to write log lines to. When
      # registering the adapter class, {Rackstash::Adapters.[]} will call
      # {initialize} with a single argument: the log device.
      def initialize(*)
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
      # This method needs to be overwritten in child classes to write the
      # encoded log event to the adapter's device. By default, this method
      # raises a `NotImplementedError`.
      #
      # @param log [Object] the encoded log event
      # @return [void]
      # @raise NotImplementedError
      def write_single(log)
        raise NotImplementedError, 'write needs to be implemented in a sub class'
      end

      private

      # Helper method to ensure that a log line passed to {#write} is a string
      # that ends in a newline character by mutating the object is required.
      #
      # @param line [#to_s] a log line
      # @return [String] a string with a trailing newline character (`"\n"`)
      def normalize_line(line)
        line = line.to_s
        line << "\n".freeze unless line.end_with?("\n".freeze)
        line
      end
    end
  end
end
