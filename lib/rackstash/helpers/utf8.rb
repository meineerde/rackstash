# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Helpers
    # Provide helper functions to help with UTF8 handling of Strings.
    module UTF8
      protected

      # Encode the given String in UTF-8. If the given `str` is already
      # correctly encoded and frozen, we just return it unchanged. In all other
      # cases we return a UTF-8 encoded and frozen copy of the string.
      #
      # @param str [String, #to_s]
      # @return [String]
      def utf8_encode(str)
        if str.instance_of?(String) && str.encoding == Encoding::UTF_8 && str.valid_encoding?
          str.frozen? ? str : str.dup.freeze
        else
          str = str.to_s
          str = str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          str.freeze
        end
      end
    end
  end
end
