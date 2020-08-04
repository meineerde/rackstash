# frozen_string_literal: true
#
# Copyright 2017-2020 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Utils
    module_function

    # Get a UTF-8 encoded frozen string representation of the given object. If
    # the object is already a correctly encoded and frozen String, we just
    # return it unchanged. In all other cases we return a UTF-8 encoded and
    # frozen copy of the string.
    #
    # @param obj [String, #to_s]
    # @return [String]
    def utf8(obj)
      if obj.instance_of?(String) && obj.encoding == Encoding::UTF_8 && obj.valid_encoding?
        obj.frozen? ? obj : obj.dup.freeze
      else
        obj = obj.to_s
        obj = obj.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        obj.freeze
      end
    end

    if defined?(Process::CLOCK_MONOTONIC)
      # Get the current timestamp as a numeric value.
      #
      # @return [Float] the current timestamp
      def clock_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    elsif Gem.win_platform?
      require 'fiddle'

      # GetTickCount64 is available since Windows Vista / Windows Server 2008
      # It retrieves the number of milliseconds that have elapsed since the
      # system was started.
      # https://docs.microsoft.com/en-gb/windows/win32/api/sysinfoapi/nf-sysinfoapi-gettickcount64
      GetTickCount64 = Fiddle::Function.new(
        Fiddle.dlopen('kernel32.dll')['GetTickCount64'],
        [],
        -Fiddle::TYPE_LONG_LONG # unsigned long long
      )

      # Get the current timestamp as a numeric value.
      #
      # @return [Float] the current timestamp
      def clock_time
        GetTickCount64.call / 1000.0
      end
    else
      # Get the current timestamp as a numeric value
      #
      # @return [Float] the current timestamp
      def clock_time
        ::Time.now.to_f
      end
    end
  end
end
