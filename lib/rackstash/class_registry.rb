# frozen_string_literal: true
#
# Copyright 2017 - 2020 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/utils'

module Rackstash
  class ClassRegistry
    include ::Enumerable

    include Rackstash::Utils

    # @return [String] the human-readable singular name of the registered
    #   objects. It is used to build more useful error messages.
    attr_reader :object_type

    # @param object_type [#to_s] the human-readable singular name of the
    #   registered objects. It is used to build more useful error messages.
    def initialize(object_type = 'class')
      @object_type = utf8(object_type)
      @registry = {}
    end

    # Retrieve the registered class for a given name. If the argument is already
    # a class, we return it unchanged.
    #
    # @param spec [Class, String, Symbol] Either a class (in which case it is
    #   returned directly) or the name of a registered class.
    # @raise [TypeError] when giving an invalid object
    # @return [Class, nil] the registered class (when giving a `String` or
    #   `Symbol`) or the given class (when giving a `Class`) or `nil` if no
    #   registered class could be found
    # @see #fetch
    def [](spec)
      fetch(spec, nil)
    end

    # Retrieve the registered class for a given name. If the argument is already
    # a class, we return it unchanged.
    #
    # @param spec [Class, String, Symbol] either a class (in which case it is
    #   returned directly) or the name of a registered class
    # @param default [Object] the default value that is returned if no
    #   registered class could be found for the given `spec` and no block was
    #   given.
    # @yield if no registered class could be found for the given `spec`, we will
    #   run the optional block and return its result
    # @yieldparam spec [Symbol] the requested class specification as a `Symbol`
    # @raise [KeyError] when giving a `String` or `Symbol` but no registered
    #   class was found for it and no default was specified
    # @raise [TypeError] when giving an invalid `spec` object
    # @return [Class] the registered class (when giving a `String` or `Symbol`)
    #   or the given class (when giving a `Class`)
    def fetch(spec, default = UNDEFINED)
      case spec
      when Class
        spec
      when String, Symbol, ->(s) { s.respond_to?(:to_sym) }
        @registry.fetch(spec.to_sym) do |key|
          next yield(key) if block_given?
          next default unless UNDEFINED.equal? default

          raise KeyError, "No #{object_type} was registered for #{spec.inspect}"
        end
      else
        raise TypeError, "#{spec.inspect} can not be used to describe " \
          "#{object_type} classes"
      end
    end

    # Register a class for the given name.
    #
    # @param name [String, Symbol] the name at which the class should be
    #   registered
    # @param registered_class [Class] the class to register at `name`
    # @raise [TypeError] if `name` is not a `String` or `Symbol`, or if
    #   `registered_class` is not a `Class`
    # @return [Class] the `registered_class`
    def []=(name, registered_class)
      unless registered_class.is_a?(Class)
        raise TypeError, 'Can only register class objects'
      end

      case name
      when String, Symbol
        @registry[name.to_sym] = registered_class
      else
        raise TypeError, "Can not use #{name.inspect} to register " \
          "#{object_type} classes"
      end
      registered_class
    end

    # Remove all registered classes
    #
    # @return [self]
    def clear
      @registry.clear
      self
    end

    # Calls the given block once for each name in `self`, passing the name and
    # the registered class as parameters.
    #
    # An `Enumerator` is returned if no block is given.
    #
    # @yield [name, registered_class] calls the given block once for each name
    # @yieldparam name [Symbol] the name of the registered class
    # @yieldparam registered_class [Class] the registered class
    # @return [Enumerator, self] `self` if a block was given or an `Enumerator`
    #   if no block was given.
    def each
      return enum_for(__method__) unless block_given?
      @registry.each_pair do |name, registered_class|
        yield name, registered_class
      end
      self
    end

    # Prevents further modifications to `self`. A `RuntimeError` will be raised
    # if modification is attempted. There is no way to unfreeze a frozen object.
    #
    # @return [self]
    def freeze
      @registry.freeze
      super
    end

    # @return [::Array<Symbol>] a new array populated with all registered names
    def names
      @registry.keys
    end

    # @return [Hash<Symbol=>Class>] a new `Hash` containing all registered
    #   names and classes
    def to_h
      @registry.dup
    end
  end
end
