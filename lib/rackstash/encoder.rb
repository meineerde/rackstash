# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # An Encoder is part of a {Flow} where they are responsible to transform the
  # filtered event into a format suitable for writing by the final log
  # {Adapter}.
  #
  # The encoder needs to be selected together with the log {Adapter}. While many
  # adapters support different encoders, some require a specific format to be
  # sent over a wire. Please consult the documentation of your desired adapter
  # for details.
  #
  # Each adapter can define their common default encoder. In a flow, you can
  # optionally overwrite the used encoder to select a different log format (e.g.
  # to log using the {Lograge} key-value syntax instead of the common default of
  # {JSON}.
  #
  # An encoder can be any object responding to `encode`, e.g. a Proc or an
  # instance of a class inside this module. Note that although Strings respond
  # to the `encode` method, they are not suitable encoders since Strings can not
  # deal with events on their own.
  module Encoder
    class << self
      # Register an encoder with one or more given names. These names can then
      # be used in {.build} to fetch the registered class and build a new
      # encoder object for it.
      #
      # @param encoder_class [Class] a class from which a new encoder can be
      #   created. Encoder classes must implement the `encode` instance method
      #   which accepts an event hash and returns encoded event.
      # @param names [Array<String,Symbol>] one or more names for the
      #   registered `encoder_class`. Using these names, the user can create a
      #   new encoder object from the registered class in {.build}.
      # @raise [TypeError] if invalid arguments were passed, e.g. an unsuitable
      #   class or invalid names
      # @return [Class] the passed `filter_class`
      def register(encoder_class, *names)
        unless encoder_class.is_a?(Class) &&
               encoder_class.instance_methods.include?(:encode)
          raise TypeError, 'Can only register encoder classes'
        end

        names.flatten.each do |name|
          registry[name] = encoder_class
        end
        encoder_class
      end

      # @return [ClassRegistry] the registry object which allows to register and
      #   retrieve available encoder classes
      def registry
        @registry ||= Rackstash::ClassRegistry.new('encoder'.freeze)
      end

      # Create a new encoder instance from the specified class and the given
      # arguments. The class can be given as an actual class or as the name of
      # an encoder in which case we are resolving it to a class registered to
      # the {.registry}.
      #
      # @param encoder_spec [Class, Symbol, String, #encode] a description of
      #   the class from which we are creating a new filter object. When giving
      #   a `Class`, we are using it as is to create a new filter object with
      #   the supplied `args` and `block`. When giving a `String` or `Symbol`,
      #   we first use the filter registry to find the matching class. With
      #   that, we then create a filter object as before. When giving an object
      #   which responds to `call` already (e.g. a `Proc`, we return it
      #   unchanged, ignoring any additional passed `args`.
      # @param args [Array] an optional list of arguments which is passed to the
      #   initializer for the new filter object.
      # @raise [TypeError] if we can not create a new filter object from the
      #   given `filter_spec`, usually because it is an unsupported type
      # @raise [KeyError] if we could not find a filter class in the registry
      #   for the specified class name
      # @return [Object] a new filter object
      def build(encoder_spec, *args, &block)
        if encoder_spec.respond_to?(:encode) && !encoder_spec.is_a?(String)
          encoder_spec
        else
          registry[encoder_spec].new(*args, &block)
        end
      end
    end
  end
end
