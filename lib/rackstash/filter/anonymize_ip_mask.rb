# frozen_string_literal: true
#
# Copyright 2018-2020 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'ipaddr'

require 'rackstash/filter'
require 'rackstash/utils'

module Rackstash
  module Filter
    # Anonymize found IP addresses by masking of a number of bits so that only
    # the network of the address remains identifiable but the specific host
    # remains anonymous.
    #
    # This is a very common approach to ensure a balance between direct
    # identification of an IP address (e.g. a client IP of a web request) and
    # the desire to anonymize it a bit. With the network still present, it is
    # possible to roughly identify the source of the request and perform
    # analysis. Usually, it's not possible anymore to identify a specific user
    # anymore though.
    #
    # You can define the number of bits that should be masked of at the end of
    # the IP address. This is not the same as a subnet mask, in fact, it is the
    # inverse. By default, we mask of 8 bits for IPv4 addresses (so that a `/24`
    # network remains) and 80 bits for IPv6 addresses (so that a `/80` network
    # remains).
    #
    # Note that IPv4-mapped IPv6 addresses as well as IPv4-compatible IPv6
    # addresses are masked off as IPv4 addresses since they actually (more or
    # less) represent an IPv4 address.
    #
    # We are writing raw String representations of the anonymized IP address to
    # the target field:
    #
    # @example
    #   Rackstash::Flow.new(STDOUT) do
    #     # Anonymize IP addresses
    #     filter :anonymize_ip_mask, {'source_ip' => 'source_ip'}
    #   end
    class AnonymizeIPMask
      include Rackstash::Utils

      # @param field_spec [Hash<#to_s => #to_s>] a `Hash` specifying which
      #   fields should be anonymized and where the result should be stored. The
      #   key described the name of the existing source field and the value the
      #   name of field where the anonymized result should be stored.
      # @param ipv4_mask [#to_i] The number of bits which are masked off at
      #   the end of an IPv4 address, i.e. that many bits at the end of an IPv4
      #   address are set to 0. Must be between 1 and 32.
      # @param ipv6_mask [#to_i] The number of bits which are masked off at
      #   the end of an IPv6 address, i.e. that many bits at the end of an IPv6
      #   address are set to 0. Must be between 1 and 128.
      def initialize(field_spec, ipv4_mask: 8, ipv6_mask: 80)
        @fields = {}
        Hash(field_spec).each_pair do |key, value|
          @fields[utf8(key)] = utf8(value)
        end

        @ipv4_mask = Integer(ipv4_mask)
        unless @ipv4_mask.between?(1, 32)
          raise ArgumentError, 'ipv4_mask must be between 1 and 32 bits'
        end

        @ipv6_mask = Integer(ipv6_mask)
        unless @ipv6_mask.between?(1, 128)
          raise ArgumentError, 'ipv6_mask must be between 1 and 128 bits'
        end
      end

      # Anonymize configured fields with IP addresses in the given `event` hash
      # by masking of the defined number of bits at the end. The anonymized IP
      # address will then be written to the target key in the event hash as a
      # simple String representation of the IP address.
      #
      # If we can not parse the value in a source field as an IP address, we
      # will not write anything to the target key in the event hash.
      #
      # @example
      #   filter = Rackstash::Filter::AnonymizeIPMask.new('source_ip' => 'anonymized_ip')
      #
      #   filter.call('source_ip' => '10.42.42.123')
      #   # => {'source_ip' => '10.42.42.123', 'anonymized_ip' => '10.42.42.0'}
      #
      #   filter.call('source_ip' => '2400:cb00:2048:1::6810:1460')
      #   # => {'source_ip' => '2400:cb00:2048:1::6810:1460', 'anonymize_ip' => '2400:cb00:2048::'}
      #
      #   # We are not writing the new value if a source can not be found
      #   filter.call('another_ip' => '192.168.42.123')
      #   # => {'another_ip' => '192.168.42.123'}
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the defined IP fields encrypted
      def call(event)
        @fields.each_pair do |source, target|
          value = anonymize(event[source])
          event[target] = value unless value.nil?
        end
        event
      end

      # Anonymize a single IP address or an array of IP addresses by masking of
      # trailing bits. When giving a single value, we return the masked IP as a
      # `String`  or `nil` if the given value is not a valid IP address. When
      # giving multiple values (i.e. an `Array` of IP addresses), we try to
      # anonymize each value separately. Only valid values will be included in
      # the returned Array.
      #
      # @param value [#to_s, Array<#to_s>] the IP address(es) to anonymize
      # @return [String, Array<String>, nil] The anonymized IP or `nil` if the
      #   given `value` was invalid. When giving an Array, we return an array of
      #   anonymized IPs. Only value source values are included.
      def anonymize(value)
        case value
        when Array
          result = []
          value.each do |element|
            anonymized = anonymize_value(element)
            result << anonymized unless anonymized.nil?
          end
          result
        when nil
          nil
        else
          anonymize_value(value)
        end
      end

      private

      # Anonymize a single IP address
      # @param value [#to_s] an IP address
      # @return [String, nil] the anonymized IP address or `nil` if the given
      #   `value` was not a valid IP address
      def anonymize_value(value)
        begin
          ip = IPAddr.new(value.to_s)
        rescue ArgumentError
          # IPAddr was not able to parse the value as an IPAddress
          return nil
        end

        if ip.ipv4?
          masked_ip = ip.mask(32 - @ipv4_mask)
        elsif ip.ipv4_mapped? || (ip.to_i >> 32) == 0
          # The `(ip.to_i >> 32) == 0` check above tests whether the IP appears
          # to be an IPv4-compatible IPv6 addresses. We do this manually to
          # avoid the deprecated `IPAddr#ipv4_compat?` method. We can perform a
          # simplified check here since after masking, the regular IPv6
          # addresses '::' and '::1' will both be masked of as '::' anyways
          # since we require to mask off at least one bit for both IPv4 and IPv6
          # addresses.
          masked_ip = ip.mask(128 - @ipv4_mask)
        elsif ip.ipv6?
          masked_ip = ip.mask(128 - @ipv6_mask)
        end

        masked_ip.to_s.force_encoding(Encoding::UTF_8) if masked_ip
      end
    end

    register AnonymizeIPMask, :anonymize_ip_mask
  end
end
