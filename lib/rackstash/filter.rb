# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/class_registry'

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
  module Filter
    class << self
      # Register a filter with one or more given names. These names can then be
      # used in {.build} to fetch the registered class and build a new filter
      # object for it.
      #
      # @param filter_class [Class] a class from which a new filter can be
      #   created. Filter classes must implement the `call` instance method
      #   which accepts an event hash.
      # @param filter_names [Array<String,Symbol>] one or more names for the
      #   registered `filter_class`. Using these names, the user can create a
      #   new filter object from the registered class in {.build}.
      # @raise [TypeError] if invalid arguments were passed, e.g. an unsuitable
      #   class or invalid names
      # @return [Class] the passed `filter_class`
      def register(filter_class, *filter_names)
        unless filter_class.is_a?(Class) &&
               filter_class.instance_methods.include?(:call)
          raise TypeError, 'Can only register filter classes'
        end

        filter_names.flatten.each do |name|
          registry[name] = filter_class
        end
        filter_class
      end

      # @return [ClassRegistry] the {ClassRegistry} object which allows to
      #   register and retrieve available filter classes
      def registry
        @registry ||= Rackstash::ClassRegistry.new('filter')
      end

      # Create a new filter instance from the specified class and the given
      # arguments. The class can be given as an actual class or as the name of a
      # filter in which case we are resolving it to a class registered to the
      # {.registry}.
      #
      # @param filter_spec [Class, Symbol, String, #call] a description of the
      #   class from which we are creating a new filter object. When giving a
      #   `Class`, we are using it as is to create a new filter object with the
      #   supplied `args` and `block`. When giving a `String` or `Symbol`, we
      #   first use the filter {.registry} to find the matching class. With that
      #   we then create a filter object as before. When giving an object which
      #   responds to `call` already (e.g. a `Proc`) we return it unchanged,
      #   ignoring any additional passed `args`, `kwargs`, or condition.
      # @param only_if [#call, Symbol, nil] An optional condition defining
      #   whether the filter should be applied,  defined as a `Proc` (or another
      #   object responding to `call`) or a Symbol. Before evaluating the newly
      #   created filter object, we first call the given proc or we call the
      #   method identified by the given Symbol on the filter object, each time
      #   giving the `event` Hash as its argument. The filter is only applied
      #   if the proc or filter method returns a truethy value.
      # @param not_if [#call, Symbol, nil] An optional condition defining
      #   whether the filter should not be applied, defined as a `Proc` (or
      #   another object responding to `call`) or a Symbol. Before evaluating
      #   the newly created filter object, we first call the given proc or we
      #   call the method identified by the given Symbol on the filter object,
      #   each time giving the `event` Hash as its argument. The filter is not
      #   applied if the proc or filter method returns a truethy value.
      # @param args [Array] an optional list of arguments which is passed to the
      #   initializer for the new filter object.
      # @param kwargs [Hash] an optional list of keyword arguments which are
      #   passed to the initializer for the new filter object.
      # @raise [TypeError] if we can not create a new filter object from the
      #   given `filter_spec`, usually because it is an unsupported type
      # @raise [KeyError] if we could not find a filter class in the registry
      #   for the specified class name
      # @return [Object] a new filter object
      def build(filter_spec, *args, only_if: nil, not_if: nil, **kwargs, &block)
        # TODO: warn if args, kwargs, only_if, not_if were given here
        #       since they are ignored
        return filter_spec if filter_spec.respond_to?(:call)

        filter_class = registry.fetch(filter_spec)
        filter = filter_class.new(*args, **kwargs, &block)

        conditional_filter(filter, only_if: only_if, not_if: not_if)
      end

      private

      def conditional_filter(filter, only_if: nil, not_if: nil)
        if only_if.nil?
          # Empty conditional, do nothing
        elsif only_if.is_a?(Symbol)
          apply_condition(filter) { |event| filter.send(only_if, event) }
        elsif only_if.respond_to?(:call)
          apply_condition(filter) { |event| only_if.call(event) }
        else
          raise TypeError, 'Invalid only_if filter'
        end

        if not_if.nil?
          # Empty conditional, do nothing
        elsif not_if.is_a?(Symbol)
          apply_condition(filter) { |event| !filter.send(not_if, event) }
        elsif not_if.respond_to?(:call)
          apply_condition(filter) { |event| !not_if.call(event) }
        else
          raise TypeError, 'Invalid not_if filter'
        end

        filter
      end

      def apply_condition(filter)
        mod = Module.new do
          define_method(:call) do |event|
            yield(event) ? super(event) : event
          end
        end
        filter.extend(mod)
      end
    end
  end
end
