# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'bigdecimal'
require 'pathname'
require 'uri'

require 'concurrent'

module Rackstash
  module Fields
    class AbstractCollection
      # Equality -- Two collections are equal if they are of exactly the same
      # class and contain the same raw data according to `Object#==`.
      #
      # @return [Boolean] `true` if `other` is an object of the same class and
      #   contains the same raw data as this object.
      def ==(other)
        self.class == other.class && raw == other.raw
      end
      alias eql? ==

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
        id_str = (object_id << 1).to_s(16).rjust(DEFAULT_OBJ_ID_STR_WIDTH, '0')
        "#<#{self.class.name}:0x#{id_str} #{self}>"
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
        self.raw = source.raw == nil ? nil : source.raw.dup
        self
      end

      def initialize_clone(source)
        super
        self.raw = source.raw == nil ? nil : source.raw.clone
        self
      end

      def new(raw)
        self.class.new.tap do |new_object|
          new_object.raw = raw
        end
      end

      # @param str [#to_s]
      def utf8_encode(str)
        str.to_s.encode(
          Encoding::UTF_8,
          invalid: :replace,
          undef: :replace
        )
      end

      def resolve_value(value, scope: nil)
        return value unless value.is_a?(Proc)
        scope == nil ? value.call : scope.instance_exec(&value)
      end

      # Note: You should never mutate an array or hash returned by normalize
      # when `wrap` is `false`.
      def normalize(value, scope: nil, wrap: true)
        value = resolve_value(value, scope: scope)

        case value
        when ::String, ::Symbol
          return utf8_encode(value).freeze
        when ::Integer, ::Float
          return value
        when true, false, nil
          return value
        when Rackstash::Fields::Hash, Rackstash::Fields::Array
          return wrap ? value : value.raw
        when ::Hash
          hash = Concurrent::Hash.new
          value.each_pair do |k, v|
            hash[utf8_encode(k)] = normalize(v, scope: scope)
          end
          if wrap
            hash = Rackstash::Fields::Hash.new.tap do |hash_field|
              hash_field.raw = hash
            end
          end
          return hash
        when ::Array, ::Set, ::Enumerator
          array = Concurrent::Array.new
          value.each do |e|
            array << normalize(e, scope: scope)
          end
          if wrap
            array = Rackstash::Fields::Array.new.tap do |array_field|
              array_field.raw = array
            end
          end
          return array
        when ::Time
          return value.utc.iso8601(ISO8601_PRECISION).freeze
        when ::DateTime
          return value.to_time.utc.iso8601(ISO8601_PRECISION).freeze
        when ::Date
          return value.iso8601.encode!(Encoding::UTF_8).freeze
        when ::Regexp, ::Range, ::URI::Generic, ::Pathname
          return utf8_encode(value).freeze
        when Exception
          exception = "#{value.message} (#{value.class})"
          exception << "\n" << value.backtrace.join("\n") if value.backtrace
          return utf8_encode(exception).freeze
        when ::Proc
          return utf8_encode(value.inspect).freeze
        when ::BigDecimal
          # A BigDecimal would be naturally represented as a JSON number. Most
          # libraries, however, parse non-integer JSON numbers directly as
          # floats. Clients using those libraries would get in general a wrong
          # number and no way to recover other than manually inspecting the
          # string with the JSON code itself.
          return value.to_s('F').encode!(Encoding::UTF_8).freeze
        when ::Complex
          # A complex number can not reliably converted to a float or rational,
          # thus we always transform it to a String
          return utf8_encode(value).freeze
        end

        # Try to convert the value to a known basic type and recurse
        %i[
          as_json
          to_hash to_ary to_h to_a
          to_time to_datetime to_date
          to_f to_i
        ].each do |method|
          # Try to convert the value to a base type but ignore any errors
          next unless value.respond_to?(method)
          value = value.public_send(method) rescue next

          return normalize(value, scope: scope, wrap: wrap)
        end

        utf8_encode(value.inspect).freeze
      end
    end
  end
end
