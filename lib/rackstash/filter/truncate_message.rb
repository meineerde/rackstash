# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  module Filter
    # The Truncate filter can be used to restrict the size of the emitted
    # message. By selectively deleting parts until the message size fits into
    # the defined limit, you can ensure that log events are properly handled by
    # downstream systems.
    #
    # We are performing the following steps, until the overall size of all
    # messages in the event is below the given maximum size or there is only one
    # message left, regardless of size:
    #
    # * Pass each message to the first selector, one after another. Each message
    #   for which the selector returns `false` or `nil` is deleted. Repeat this
    #   for each given selector until either the overall message size is below
    #   the defined `max_size` or there are no further selectors.
    # * If the overall message size is still above `max_size`, we start to
    #   delete messages at the `truncate` location until we have either achieved
    #   the desired size limit or we have only one message left. With
    #   `cut: top` we start to delete messages first at the beginning of the
    #   message list, with `cut: :bottom` (the default) with the very last
    #   message and with `cut: :middle` we are deleting from the middle of the
    #   message list preserving the messages at the beginning and the end.
    #   If there are any messages deleted in this last step, we insert the
    #   `elipsis` once at the location where the messages were removed.
    #
    # Note that in any case, we are only ever deleting whole messages (which
    # usually but not necessarily amount to whole lines). We are not splitting
    # messages.
    #
    # @example
    #   Rackstash::Flow.new(STDERR) do
    #     # Truncate the message to at most 1 MByte.
    #     # We try the following steps to cut a too large message down:
    #     #   * We select all messages with at least INFO level, removing debug
    #     #     messages.
    #     #   * If it's still too large, we also remove INFO messages, keeping
    #     #     only messages with a WARN severity or above
    #     #   * If it's still too large, we remove log lines from the middle of
    #     #     the messages until we reach the desired size.
    #     filter :truncate_message,
    #       1_000_000,
    #       selectors: [
    #         ->(message) { message.severity >= Rackstash::INFO },
    #         ->(message) { message.severity >= Rackstash::WARN }
    #       ],
    #       cut: :middle
    #   end
    class TruncateMessage
      ELLIPSIS = "[...]\n".freeze

      # @param max_size [Integer] The maximum desired number of characters for
      #   all the messages in an event combined
      # @param selectors [Array<#call>] An optional list of message filters
      #   (e.g. `Proc` objects) which accept a single message. When returning
      #   `nil` or `false`, the message is rejected.
      # @param cut [Symbol] where to start removing messages if the message list
      #   is still too large after all filters were applied. One of `:top`,
      #   `:middle`, or `:bottom`.
      # @param ellipsis [String] A string to insert at the location where lines
      #   were removed by the final cut (if any) to mark the location in the
      #   logs. Set this to `nil` to not insert an ellipsis.
      def initialize(max_size, selectors: [], cut: :bottom, ellipsis: ELLIPSIS)
        @max_size = Integer(max_size)
        @selectors = Array(selectors)

        unless %i[top middle bottom].include?(cut)
          raise ArgumentError, 'cut must be one of :top, :middle, :bottom'
        end
        @cut = cut
        @ellipsis = ellipsis
      end

      # Remove messages if the overall size in bytes of all the messages in the
      # given event is larger than the desired `max_size`.
      #
      # @param event [Hash] an event hash
      # @return [Hash] the given `event` with the some messages potentially
      #   removed
      def call(event)
        messages = event[FIELD_MESSAGE]
        return event unless Array === messages

        @selectors.each do |selector|
          return event if overall_size_of(messages) <= @max_size || messages.size <= 1
          if selector.is_a?(Proc)
            messages.select!(&selector)
          else
            messages.select! { |message| selector.call(message) }
          end
        end
        return event if messages.size <= 1

        truncate(messages)

        event
      end

      private

      def truncate(messages)
        overall_size = overall_size_of(messages)
        ellipsis = nil

        until overall_size <= @max_size || messages.size <= 1
          msg =
            case @cut
            when :top
              messages.shift
            when :middle
              messages.delete_at(messages.size / 2)
            when :bottom
              messages.pop
            end

          overall_size -= msg.size

          unless ellipsis || @ellipsis.nil?
            ellipsis = Rackstash::Message.new(@ellipsis)
            overall_size += ellipsis.size
          end
        end

        # Insert the ellipsis message if we have truncated any messages
        insert_into(messages, ellipsis) if ellipsis

        messages
      end

      def insert_into(messages, msg)
        case @cut
        when :top
          messages.unshift(msg)
        when :middle
          messages.insert((messages.size + 1) / 2, msg)
        when :bottom
          messages.push(msg)
        end

        messages
      end

      def overall_size_of(messages)
        messages.inject(0) { |sum, msg| sum + msg.size }
      end
    end
  end
end
