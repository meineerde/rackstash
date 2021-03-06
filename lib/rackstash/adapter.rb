# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'uri'

module Rackstash
  module Adapter
    class << self
      # Register a concrete adapter class which can be instanciated with a
      # certain log device (e.g. a file name, an IO object, a URL specifying a
      # log target, ...). With the provided `matchers`, a class can describe
      # which kind of log devices are suitable to be used with it:
      #
      # * `String` as class name - When passing a string that starts with an
      #   uper-case character, we assume it to represent a class name. When
      #   retrieving a matching adapter for a device, we check if the name of
      #   the device's class matches this string. This can be used to register
      #   an adapter for a device which might not be loaded (yet), e.g. from an
      #   external gem. If possible, you should register the adapter for the
      #   actual class instead of its name.
      # * `String` as URI scheme - When passing a string that doesn't start with
      #   an uper-case character, we register it as the scheme of a URI. When
      #   retrieving an adapter for a URI in {[]}, we check if the URI's scheme
      #   matches this string.
      # * `Symbol` - When passing a symbol, we check if the resolved device
      #   responds to an equally named method.
      # * An object responding to the `===` method - When retrieving an adapter
      #   for a device, we are comparing the matcher object to the device. This
      #   is the same comparison as done in a `case ... when` statement in Ruby.
      #   Usually, the matcher object is either a class or module (in which case
      #   we check if the device object inherits from the matcher) or a proc,
      #   accepting an object as its first parameter. When checking this
      #   matcher, the proc gets called with the device as its parameter. If the
      #   proc returns a truethy value, we use it to build the adapter instance.
      #
      # @param adapter_class [Class] a concrete adapter class
      # @param matchers [Array<String, Symbol, #===>] a list of specifications
      #   for log devices the `adapter_class` can forward logs to.
      # @raise [TypeError] if the passed adapter_class is not a class
      #   inheriting from {BaseAdapter}
      # @return [Class] the `adapter_class`
      def register(adapter_class, *matchers)
        unless adapter_class.is_a?(Class) && adapter_class < BaseAdapter
          raise TypeError, 'adapter_class must be a class and inherit from ' \
            'Rackstash::Adapter::BaseAdapter'
        end

        matchers.flatten.each do |matcher|
          case matcher
          when String
            matcher = matcher.to_s
            if matcher =~ /\A[A-Z]/
              # If the matcher starts with a upper-case characters, we assume it
              # is a class name.

              # Since we use `compare_by_identity` for types, we need to ensure
              # that we can override existing class names.
              adapter_types.delete_if { |key, _value| key == matcher }
              adapter_types[matcher] = adapter_class
            elsif !matcher.empty?
              # If the matcher is a lower-case string, we assume it is a URL
              # scheme.
              adapter_schemes[matcher] = adapter_class
            else
              raise TypeError, "invalid matcher: #{matcher}"
            end
          when Symbol, ->(o) { o.respond_to?(:===) }
            adapter_types[matcher] = adapter_class
          else
            # Should not be reached by "normal" objects since `Object` already
            # responds to `===` (which is the same as `==` by default)
            raise TypeError, "invalid matcher: #{matcher}"
          end
        end

        adapter_class
      end

      # Try to build an adapter instance from the passed `device`. If the
      # `device` is already an {Adapter}, it is returned unchanged. If not, we
      # attempt to identify a suitable adapter class from the {register}ed
      # classes and return a new adapter instance.
      #
      # if no suitable adapter can be found, we raise an `ArgumentError`.
      #
      # @param device [BaseAdapter, Object] a log device which should be
      #   wrapped in an adapter object. If it is already an adapter, the
      #   `device` is returned unchanged.
      # @raise [ArgumentError] if no suitable adapter could be found for the
      #   provided `device`
      # @return [Adapter::Adapter] the resolved adapter instance
      def [](device)
        return device if device.is_a?(BaseAdapter)

        adapter   = adapter_by_uri_scheme(device)
        adapter ||= adapter_by_type(device)

        unless adapter
          raise ArgumentError, "No log adapter found for #{device.inspect}"
        end
        adapter
      end

      private

      def adapter_by_uri_scheme(uri)
        uri = URI(uri) rescue return
        return unless uri.scheme

        adapter_class = adapter_schemes.fetch(uri.scheme) {
          # `uri` might look like a windows path, e.g. C:/path/to/file.log
          return if ('a'..'z').include?(uri.scheme.downcase)
          raise ArgumentError, "No log adapter found for URI #{uri}"
        }

        if adapter_class.respond_to?(:from_uri)
          adapter_class.from_uri(uri)
        else
          adapter_class.new(uri)
        end
      end

      def adapter_by_type(device)
        adapter_types.each do |type, adapter_class|
          suitable =
            if type.is_a?(Symbol)
              device.respond_to?(type)
            elsif type.is_a?(String)
              device.class.ancestors.any? { |klass| type == klass.name }
            else
              type === device
            end

          return adapter_class.new(device) if suitable
        end
        nil
      end

      def adapter_schemes
        @adapter_schemes ||= {}
      end

      def adapter_types
        @adapter_types ||= {}.compare_by_identity
      end
    end
  end
end
