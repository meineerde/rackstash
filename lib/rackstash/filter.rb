# frozen_string_literal: true
#
# Copyright 2017 Holger Just
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
      #   created. Filter objects must respond to `call` and accept an event
      #   hash.
      # @param filter_names [Array<String,Symbol>] one or more names for the
      #   registered `filter_class`. Using these names, the user can create a
      #   new filter object from the registered class in {.build}.
      # @raise [TypeError] if objects of type were passed
      # @return [Class] the passed `filter_class`
      def register(filter_class, *filter_names)
        filter_names.flatten.each do |name|
          registry[name] = filter_class
        end
        filter_class
      end

      # @return [ClassRegistry] the {ClassRegistry} object which allows to
      #   register and retrieve available filter classes
      def registry
        @registry ||= Rackstash::ClassRegistry.new('filter'.freeze)
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
      #   responds to `call` already (e.g. a `Proc`, we return it unchanged,
      #   ignoring any additional passed `args`.
      # @param only_if [#call, nil] An optional condition defining whether the
      #   filter should be applied, usually given as a `Proc` object. Before
      #   evaluating the newly created filter object, we first call the given
      #   proc with the event as its argument. The filter is applied only if the
      #   proc returns a truethy value.
      # @param not_if [#call, nil] An optional condition defining whether the
      #   filter should not be applied, usually given as a `Proc` object. Before
      #   evaluating the newly created filter object, we first call the given
      #   proc with the event as its argument. The filter is not applied if the
      #   proc returns a truethy value.
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
        case filter_spec
        when ->(filter) { filter.respond_to?(:call) }
          filter_spec
        else
          args << kwargs unless kwargs.empty?

          filter = registry[filter_spec].new(*args, &block)
          conditional_filter(filter, only_if: only_if, not_if: not_if)
        end
      end

      private

      def conditional_filter(filter, only_if: nil, not_if: nil)
        return filter if only_if.nil? && not_if.nil?

        conditional = Module.new do
          define_method(:call) do |event|
            return event if only_if && !only_if.call(event)
            return event if not_if && not_if.call(event)
            super(event)
          end
        end
        filter.extend(conditional)
      end
    end
  end
end
