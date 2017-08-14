# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/filters/clear_color'
require 'rackstash/filters/skip_event'

module Rackstash
  # Filters are part of a {Flow} where they can alter the log event before it is
  # passed to the encoder and finally to the adapter. With filters, you can add,
  # change or delete fields. Since each flow uses its own copy of a log event,
  # you can use a different set of filters per flow and can adapt the event
  # anyway you require.
  #
  # You can e.g. remove unenessary fields, anonymize logged IP addresses or
  # filter messages. In its `call` method, the passed event hash can be mutated
  # in any way. Since the event hash includes an array of {Message} objects in
  # `event["messages"]` which provide the original severity and timestamp of
  # each logged message, you can also retrospectively filter the logged messages.
  #
  # A filter can be any object responding to `call`, e.g. a Proc or a concrete
  # class inside this module.
  module Filters
    # Create a new filter instance from the specified class and the given
    # arguments. The class can be given as an actual class or as the name of a
    # filter in which case we are resolving it to a class defined inside the
    # {Rackstash::Filters} namespace.
    #
    # @param klass [Class, Symbol, String] a description of the class from which
    #   we are creating a new filter object. When giving a `Class`, we are using
    #   it as is. When giving a `String` or `Symbol`, we are determining the
    #   associated class from the {Rackstash::Filters} module and create an
    #   instance of that.
    # @param args [Array] an optional list of arguments which is passed to the
    #   initializer for the new filter object.
    # @raise [TypeError] if we can not create a new Filter object from `class`
    # @raise [NameError] if we could not find a filter class for the specified
    #   class name
    # @return [Object] a new filter object
    def self.build(klass, *args, &block)
      case klass
      when Class
        klass.new(*args, &block)
      when Symbol, String
        filter_class_name = klass.to_s
          .sub(/^[a-z\d]*/) { $&.capitalize }
          .gsub(/(?:_)([a-z\d]*)/) { $1.capitalize }
          .to_sym
        filter_class = const_get(filter_class_name, false)
        filter_class.new(*args, &block)
      else
        raise TypeError, "Can not build filter for #{klass.inspect}"
      end
    end

    # @return [Hash<Symbol => Class>] a Hash with names of filters and their
    #   respective classes which can be used with {Filters.build} to create a
    #   new filter object
    def self.known
      constants.each_with_object({}) do |const, known|
        filter_class = const_get(const, false)
        next unless filter_class.is_a?(Class)

        filter_class_name = const.to_s
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
          .to_sym

        known[filter_class_name] = filter_class
      end
    end
  end
end
