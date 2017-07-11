# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # Fields are specialized data storage classes which ensure consistent and
  # strictly normalized data. They are used to store additional information
  # besides just log messages in a {Buffer}.
  #
  # Field classes are modeled after classes in Ruby core and generally provide
  # the exact interface and semantics with the notable exception that the
  # classes always ensure that any store data is directly mappable to JSON. As
  # such, all stored data is always normalized in insert and converted to the
  # respective base-types.
  module Fields
  end
end

require 'rackstash/fields/abstract_collection'
require 'rackstash/fields/hash'
require 'rackstash/fields/array'
require 'rackstash/fields/tags'
