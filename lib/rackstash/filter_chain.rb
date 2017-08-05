# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'monitor'

module Rackstash
  # The FilterChain contains a list of event filters which are used by a {Flow}
  # to mutate an event before it is envoded and sent to the adapter for writing.
  #
  # A filter is any object responding to `call`, e.g. one of the {Filters} or a
  # `Proc` object. When running the filters, we call each filter iin turn,
  # passing the event. The filter can change the event in any way desired but
  # should make sure that it preserves the basic structure of the event:
  #
  # * Only use basic objects: `Hash`, `Array`, `String`, `Integer`, `Float`.
  # * Hash keys should always be strings
  #
  # Objects of this class are thread-save. Each method call is locked against
  # `self`.
  class FilterChain
    include MonitorMixin

    def initialize(filters = [])
      mon_initialize

      @filters = []
      Array(filters).each do |filter|
        append(filter)
      end
    end

    # Get an existing filter at `index`.
    #
    # @param index [Integer, Class, String, Object] The existing filter to
    #   fetch. It can be described in different ways: When given an `Integer`,
    #   we expect it to be the index number; when given a `Class`, we try to
    #   find the first filter being of that type; when given a `String`, we try
    #   to find the first filter being of a type named like that; when given any
    #   other object, we assume it is a filter and search for that.
    # @return [#call, nil] The existing filter or `nil` if no existing filter
    #   could be found for `index`
    def [](index)
      synchronize do
        index = index_at(index)
        index ? @filters[index] : nil
      end
    end

    # Set the new filter at the given index or at the end of the chain if the
    # value at `index` could not be found.
    #
    # @param index [Integer, Class, String, Object] The existing filter which
    #   should be overwritten with `filter`. It can be described in different
    #   ways: When given an `Integer`, we expect it to be the index number; when
    #   given a `Class`, we try to find the first filter being of that type;
    #   when given a `String`, we try to find the first filter being of a type
    #   named like that; when given any other object, we assume it is a filter
    #   and search for that.
    # @param filter [#call, nil] the filter to set at `index`
    # @return [#call] the given `filter`
    def []=(index, filter)
      raise TypeError, 'must provide a filter' unless filter.respond_to?(:call)

      synchronize do
        id = index_at(index)
        unless id && (0..@filters.size).cover?(id)
          raise ArgumentError, "Cannot insert at index #{index.inspect}"
        end

        @filters[id] = filter
      end
      filter
    end

    # Adds a new filter at the end of the filter chain. You can either give a
    # callable object (e.g. a `Proc` or one of the {Filters}) or specify the
    # filter with a given block.
    #
    # @param filter [#call, nil] a filter to add. If given, this value will
    #   take precedence to the block. If `nil`, we expect a block to be given
    #   which we will then take as the filter.
    # @raise [TypeError] if the given filter is not callable
    # @return [self]
    def append(*filter_spec, &block)
      filter = build_filter(filter_spec, &block)

      synchronize do
        @filters.push filter
      end
      self
    end
    alias << append

    # Filter the given event by calling each defined filter with it.
    #
    # Each filter will be called with the current event and can manipulate it
    # in any way. If any of the filters returns `false`, no further filter will
    # be applied and we also return `false`. This behavior can be used by
    # filters to cancel the writing of an individual event.
    #
    # @param event [Hash] an event hash, see {Sink#write} for details
    # @return [Hash, false] the filtered event or `false` if any of the
    #   filters returned `false`
    def call(event)
      each do |filter|
        result = filter.call(event)
        return false if result == false
      end
      event
    end

    # Delete an existing filter from the filter chain.
    #
    # @param index [Integer, Class, String, Object] The existing filter to
    #   delete. It can be described in different ways: When given an `Integer`,
    #   we expect it to be the index number; when given a `Class`, we try to
    #   find the first filter being of that type; when given a `String`, we try
    #   to find the first filter being of a type named like that; when given any
    #   other object, we assume it is a filter and search for that.
    # @raise [ArgumentError] if the existing filter could not be found
    # @return [#call, nil] the deleted filter or `nil` if no filter for `index`
    #   could be found
    def delete(index)
      synchronize do
        index = index_at(index)
        @filters.delete_at(index) if index
      end
    end

    # Calls the given block once for each filter in `self`, passing that filter
    # as a parameter. Concurrent changes to `self` do not affect the running
    # enumeration.
    #
    # An `Enumerator` is returned if no block is given.
    #
    # @yield [filter] calls the given block once for each filter
    # @yieldparam filter [#call] the yielded filter
    # @return [Enumerator, self] Returns `self` if a block was given or an
    #   `Enumerator` if no block was given.
    def each
      return enum_for(__method__) unless block_given?
      synchronize { @filters.dup }.each do |filter|
        yield filter
      end
      self
    end

    # Returns the index of the first filter in `self` matching
    #
    # @param filter [Integer, Class, String, Object] The existing filter to
    #   find. It can be described in different ways: When given an `Integer`,
    #   we expect it to be the index number; when given a `Class`, we try to
    #   find the first filter being of that type; when given a `String`, we try
    #   to find the first filter being of a type named like that; when given any
    #   other object, we assume it is a filter and search for that.
    # @return [Integer, nil] The index of the existing filter or `nil` if no
    #   filter could be found for `index`
    def index(filter)
      synchronize { index_at(filter) }
    end

    # Insert a new filter after an existing filter in the filter chain.
    #
    # @param index [Integer, Class, String, Object] The existing filter after
    #   which the new one should be inserted. It can be described in different
    #   ways: When given an `Integer`, we expect it to be the index number; when
    #   given a `Class`, we try to find the first filter being of that type;
    #   when given a `String`, we try to find the first filter being of a type
    #   named like that; when given any other object, we assume it is a filter
    #   and search for that.
    # @param filter [#call, nil] a filter to insert. If given, this value will
    #   take precedence to the block. If `nil`, we expect a block to be given
    #   which we will then take as the filter.
    # @raise [TypeError] if the given filter is not callable
    # @raise [ArgumentError] if the existing filter could not be found
    # @return [self]
    def insert_after(index, *filter_spec, &block)
      filter = build_filter(filter_spec, &block)

      synchronize do
        id = index_at(index)
        unless id && (0...@filters.size).cover?(id)
          raise ArgumentError, "No such filter to insert after: #{index.inspect}"
        end

        @filters.insert(id + 1, filter)
      end
      self
    end

    # Insert a new filter before an existing filter in the filter chain.
    #
    # @param index [Integer, Class, String, Object] The existing filter before
    #   which the new one should be inserted. It can be described in different
    #   ways: When given an `Integer`, we expect it to be the index number; when
    #   given a `Class`, we try to find the first filter being of that type;
    #   when given a `String`, we try to find the first filter being of a type
    #   named like that; when given any other object, we assume it is a filter
    #   and search for that.
    # @param filter [#call, nil] a filter to insert. If given, this value will
    #   take precedence to the block. If `nil`, we expect a block to be given
    #   which we will then take as the filter.
    # @raise [TypeError] if the given filter is not callable
    # @raise [ArgumentError] if the existing filter could not be found
    # @return [self]
    def insert_before(index, *filter_spec, &block)
      filter = build_filter(filter_spec, &block)

      synchronize do
        id = index_at(index)
        unless id && (0...@filters.size).cover?(id)
          raise ArgumentError, "No such filter to insert before: #{index.inspect}"
        end

        @filters.insert(id, filter)
      end
      self
    end
    alias insert insert_before

    # @return [String] a string representation of `self`
    def inspect
      synchronize do
        id_str = Object.instance_method(:to_s).bind(self).call[2..-2]
        "#<#{id_str} #{self}>"
      end
    end

    # @return [Integer] the number of elements in `self`. May be zero.
    def length
      synchronize { @filters.length }
    end
    alias count length
    alias size length

    # Prepends a new filter at the beginning of the filter chain. You can either
    # give a callable object (e.g. a `Proc` or one of the {Filters}) or specify
    # the filter with a given block.
    #
    # @param filter [#call, nil] a filter to prepend. If given, this value will
    #   take precedence to the block. If `nil`, we expect a block to be given
    #   which we will then take as the filter.
    # @raise [TypeError] if the given filter is not callable
    # @return [self]
    def unshift(*filter_spec, &block)
      filter = build_filter(filter_spec, &block)

      synchronize do
        @filters.unshift filter
      end
      self
    end

    # Returns an Array representation of the filter chain.
    #
    # @return [Array<#call>] an array of filters
    def to_a
      synchronize { @filters.dup }
    end

    # @return [String] an Array-compatible string representation of `self`
    def to_s
      synchronize { @filters.to_s }
    end

    private

    def initialize_copy(orig)
      super

      mon_initialize
      synchronize do
        @filters = orig.to_a
      end
    end

    def index_at(index)
      case index
      when Integer, ->(o) { o.respond_to?(:to_int) }
        index.to_int
      when Class
        @filters.index { |filter| filter.is_a?(index) }
      when Symbol, String
        index = index.to_s
        @filters.index { |filter| filter.class.ancestors.map(&:name).include?(index) }
      else
        @filters.index { |filter| filter == index }
      end
    end

    def build_filter(filter_spec, &block)
      if filter_spec.empty?
        return block if block_given?
        raise ArgumentError, 'Need to specify a filter'
      elsif filter_spec.length == 1 && filter_spec.first.respond_to?(:call)
        filter_spec.first
      else
        Rackstash::Filters.build(*filter_spec, &block)
      end
    end
  end
end
