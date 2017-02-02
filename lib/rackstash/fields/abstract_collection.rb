# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'bigdecimal'
require 'pathname'
require 'uri'

module Rackstash
  module Fields
    class AbstractCollection
      def ==(other)
        self.class == other.class && raw == other.raw
      end
      alias :eql? :==

      def inspect
        "#<#{self.class}:#{format '0x%014x', object_id << 1} #{to_s}>"
      end

      # Provide a copy of the wrapped {#raw} data in a format allowing direct
      # mapping to JSON.
      #
      # @note This method is usually overridden in child classes.
      def as_json(*)
        nil
      end

      def to_json(*)
        as_json.to_json
      end

      def to_s
        as_json.inspect
      end

      protected

      attr_accessor :raw

      private

      def initialize_copy(source)
        super
        self.raw = source.raw == nil ? nil : source.raw.dup
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
      def normalize(value, resolve: true, scope: nil, wrap: true)
        value = resolve_value(value, scope: scope) if resolve

        case value
        when ::String, ::Symbol
          return utf8_encode(value).freeze
        when ::Integer, ::Float
          return value
        when true, false, nil
          return value
        when Rackstash::Fields::AbstractCollection
          return wrap ? value : value.raw
        when ::Hash
          hash = value.each_with_object({}) do |(k, v), memo|
            memo[utf8_encode(k)] = normalize(v, scope: scope, resolve: resolve)
          end
          hash = Rackstash::Fields::Hash.new.tap do |hash_field|
            hash_field.raw = hash
          end if wrap
          return hash
        when ::Array, ::Set, ::Enumerator
          array = value.map { |e| normalize(e, scope: scope, resolve: resolve) }
          array = Rackstash::Fields::Array.new.tap do |array_field|
            array_field.raw = array
          end if wrap
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
          return resolve ? utf8_encode(value.inspect).freeze : value
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

          return normalize(value, scope: scope, wrap: wrap, resolve: resolve)
        end

        utf8_encode(value.inspect).freeze
      end
    end
  end
end
