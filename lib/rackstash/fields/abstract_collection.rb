# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'bigdecimal'
require 'pathname'
require 'uri'

require 'concurrent'

require 'rackstash/helpers'

module Rackstash
  module Fields
    class AbstractCollection
      include Rackstash::Helpers::UTF8

      # Equality - Two collections are equal if they are of exactly the same
      # class and contain the same raw data according to `Object#==`.
      #
      # @return [Boolean] `true` if `other` is an object of the same class and
      #   contains the same raw data as this object.
      def ==(other)
        self.class == other.class && raw == other.raw
      end
      alias eql? ==

      # Prevents further modifications to `self`. A `RuntimeError` will be
      # raised if modification is attempted. There is no way to unfreeze a
      # frozen object.
      #
      # @return [self]
      def freeze
        raw.freeze
        super
      end

      # Compute a hash-code for this collection.
      #
      # Two collections with the same raw content will have the same hash code
      # (and will compare using {#eql?}).
      #
      # @return [Integer] the hash ID of `self`
      def hash
        [self.class, raw].hash
      end

      # Show a human-readable representation of `self`. To get a machine-
      # readable "export" of the contained data, use {#as_json} or one of its
      # aliases instead.
      #
      # @return [String] human-redable details about the object.
      def inspect
        id_str = Object.instance_method(:to_s).bind(self).call[2..-2]
        "#<#{id_str} #{self}>"
      end

      # Provide a copy of the wrapped {#raw} data in a format allowing direct
      # mapping to JSON.
      #
      # @note This method is usually overridden in child classes.
      def as_json(*)
        nil
      end

      # @return [String] a JSON document of the raw data. This method
      #   requires the JSON module to be required.
      def to_json(*)
        as_json.to_json
      end

      # @return [String] a string representation of {#as_json}.
      def to_s
        as_json.inspect
      end

      protected

      attr_accessor :raw

      private

      def initialize_dup(source)
        super
        self.raw = source.raw.nil? ? nil : source.raw.dup
        self
      end

      def initialize_clone(source)
        super
        self.raw = source.raw.nil? ? nil : source.raw.clone
        self
      end

      def new(raw)
        self.class.new.tap do |new_object|
          new_object.raw = raw
        end
      end

      def resolve_value(value, scope: nil)
        return value unless Proc === value

        return value.call if scope.nil?
        value.arity == 0 ? scope.instance_exec(&value) : value.call(scope)
      end

      # Note: You should never mutate an array or hash returned by normalize
      # when `wrap` is `false`.
      def normalize(value, scope: nil, wrap: true)
        value = resolve_value(value, scope: scope)

        case value
        when ::String
          utf8_encode(value)
        when ::Symbol
          utf8_encode(value.to_s.freeze)
        when ::Integer, ::Float
          value
        when true, false, nil
          value
        when ::Proc
          resolved = resolve_value(value)
          normalize(resolved, scope: scope, wrap: wrap)
        when Rackstash::Fields::Hash, Rackstash::Fields::Array
          wrap ? value : value.raw
        when ::Hash
          hash = {}
          value.each_pair do |k, v|
            hash[utf8_encode(k)] = normalize(v, scope: scope)
          end
          if wrap
            hash = Rackstash::Fields::Hash.new.tap do |hash_field|
              hash_field.raw = hash
            end
          end
          hash
        when ::Array, ::Set, ::Enumerator
          array = value.map { |e| normalize(e, scope: scope) }
          if wrap
            array = Rackstash::Fields::Array.new.tap do |array_field|
              array_field.raw = array
            end
          end
          array
        when ::Time
          value.getutc.iso8601(ISO8601_PRECISION).freeze
        when ::DateTime
          value.to_time.utc.iso8601(ISO8601_PRECISION).freeze
        when ::Date
          value.iso8601.encode!(Encoding::UTF_8).freeze
        when ::Regexp, ::Range, ::URI::Generic, ::Pathname
          utf8_encode(value.to_s.freeze)
        when Exception
          exception = "#{value.message} (#{value.class})"
          exception = [exception, *value.backtrace].join("\n") if value.backtrace
          utf8_encode(exception.freeze)
        when ::BigDecimal
          # A BigDecimal would be naturally represented as a JSON number. Most
          # libraries, however, parse non-integer JSON numbers directly as
          # floats. Clients using those libraries would get in general a wrong
          # number and no way to recover other than manually inspecting the
          # string with the JSON code itself.
          value.to_s('F').encode!(Encoding::UTF_8).freeze
        when ::Complex, ::Rational
          # A complex number can not reliably converted to a float or rational,
          # thus we always transform it to a String
          utf8_encode(value)
        else
          # Try to convert the value to a known basic type and recurse
          converted = UNDEFINED
          %i[
            as_json
            to_hash to_ary to_h to_a
            to_time to_datetime to_date
            to_f to_i
          ].each do |method|
            # Try to convert the value to a base type but ignore any errors
            begin
              next unless value.respond_to?(method)
              break converted = value.public_send(method)
            rescue
              next
            end
          end

          if UNDEFINED.equal?(converted)
            # The object doesn't seem to respond to any of the common converter
            # methods. As a final effort, we try to inspect the object and use
            # this value. If even inspecting fails (w.g. for BasicObjects), we
            # try to force-inspect the object using our own inspect
            # implementation.
            converted = value.inspect rescue force_inspect(value)
          end

          normalize(converted, scope: scope, wrap: wrap)
        end
      end

      def force_inspect(value)
        obj_id_str_width = 0.size == 4 ? 7 : 14
        obj_id = value.__id__ rescue 0

        id_str = (obj_id << 1).to_s(16).rjust(obj_id_str_width, '0')

        class_name = begin
          value.class.name
        rescue
          Kernel.instance_method(:class).bind(value).call
        end

        "#<#{class_name}:0x#{id_str}>".freeze
      end
    end
  end
end
