# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/adapter'
require 'rackstash/encoder'
require 'rackstash/filter'
require 'rackstash/filter_chain'

module Rackstash
  # A Flow is responsible for taking a raw log event (originally corresponding
  # to a single {Buffer}), transforming it and finally sending it to an adapte
  # for persistence. A Flow instance is normally tied to a {Flows} list which in
  # turn belongs to a {Logger}.
  #
  # In order to transform and persist log events, a Flow uses several
  # components:
  #
  # * Any number of {Filter}s (zero or more). The filters can change the log
  #   event before it is passed to the adapter by adding, changing, or removing
  #   fields. The filters also have access to the array of {Message} objects in
  #   `event["messages"]` which provide the original severity and timestamp of
  #   each message.
  # * An `Encoder` which is responsible to transform the filtered event into a
  #   format suitable for the final log adapter. Most of the time, the encoder
  #   generates a String but can also produce other formats. Be sure to chose
  #   an encoder which matches the adapter's expectations. Usually, this is one
  #   of the {Encoder}s.
  # * And finally the log `Adapter` which is responsible to send the encoded log
  #   event to an external log target, e.g. a file or an external log receiver.
  #   When setting up the flow, you can either provide an existing adapter
  #   object or provide an object which can be wrapped in an adapter. See
  #   {Adapter} for a list of pre-defined log adapters.
  #
  # You can build a Flow using a simple DSL:
  #
  #     flow = Rackstash::Flow.new(STDOUT) do
  #       # Anonymize IPs in the remote_ip field using the
  #       # Rackstash::Filter::AnonymizeIPMask filter.
  #       filter :anonymize_ip_mask, 'remote_ip'
  #
  #       # Add the maximum severity of any message in the event into the
  #       # severity and severity_label fields.
  #       filter do |event|
  #         severity = event['messages'].max_by { |message| message.severity }
  #         severity_label = Rackstash.severity_label(severity)
  #
  #         event['severity'] = severity
  #         event['severity_label'] = severity_label
  #       end
  #
  #       # Encode logs as JSON using a Rackstash::Encoder::JSON encoder
  #       # This is usually the default encoder.
  #       encoder :json
  #     end
  #
  #     # Write an event. This is normally done by a Rackstash::Buffer
  #     flow.write(an_event)
  #
  # The event which eventually gets written to the flow is usually created from
  # a {Buffer} with its pending data.
  class Flow
    # @return [Adapter::Adapter] the log adapter
    attr_reader :adapter

    # @return [FilterChain] the mutable filter chain.
    attr_reader :filter_chain

    # @param adapter [Adapter::Adapter, Object] an adapter or an object which
    #   can be wrapped in an adapter. See {Adapter.[]}
    # @param encoder [#encode] an encoder, usually one of the {Encoder}s. If
    #   this is not given, the adapter's default_encoder will be used.
    # @param filters [Array<#call>] an array of filters. Can be a pre-defined
    #   {Filter}, a `Proc`, or any other object which responds to `call`.
    # @param error_flow [Flow] a special flow which is used to write details
    #   about any occured errors during writing. By default, we use the global
    #   {Rackstash.error_flow} which logs JSON-formatted messages to `STDERR`.
    # @param auto_flush [Bool] set to `true` to write added fields or messages
    #   added to a {Buffer} to this flow immediately. With each write, this flow
    #   will then receive all current fields of the {Buffer} but only the
    #   currently added message (if any). When set to `false`, the flow will
    #   receive the full event with all fields and messages of the Buffer after
    #   an explicit call to {Buffer#flush} for a buffering Buffer or after each
    #   added message or fields for a non-bufering Buffer.
    # @param synchronous [Bool] set to `true` to write events synchronously.
    #   When writing events, the caller will thus block until the event was
    #   written or an error occured (which will be raised to the caller after
    #   being logged to the {#error_flow}). By default (or when explicitly
    #   setting the `synchronous` attribute to `false`), we write events
    #   asynchronously. Here, we return to the caller immediately on {#write}.
    #   Any errors occuring during logging will be logged to the {#error_flow}
    #   but will not be re-raised to the caller.
    # @yieldparam flow [self] if the given block accepts an argument, we yield
    #   `self` as a parameter, else, the block is directly executed in the
    #   context of `self`.
    def initialize(adapter, encoder: nil, filters: [],
      error_flow: nil, auto_flush: false, synchronous: false,
      &block
    )
      @adapter = Rackstash::Adapter[adapter]
      self.encoder = encoder || @adapter.default_encoder
      @filter_chain = Rackstash::FilterChain.new(filters)
      self.error_flow = error_flow
      self.auto_flush = auto_flush

      @synchronous = !!synchronous
      @executor = if synchronous?
        ::Concurrent::ImmediateExecutor.new
      else
        ::Concurrent::SingleThreadExecutor.new(fallback_policy: :abort)
      end


      if block_given?
        if block.arity == 0
          instance_eval(&block)
        else
          yield self
        end
      end
    end

    # Get or set the `auto_flush` setting. If set to `true`, new messages and
    # fields added to a {Buffer} will be written directly to this flow,
    # regardless of the buffering setting of the {Buffer}. This can be useful
    # during development or testing of an application where the developer might
    # want to directly watch the low-cardinality log as the messages are logged.
    #
    # If set to `false` (the default), buffering Buffers will only be written
    # after explicitly calling {Buffer#flush} on them.
    #
    # @param bool [Bool, nil] the value to set. If omitted, we return the
    #   current setting.
    # @return [Bool] the updated or current `auto_flush` setting
    # @see #auto_flush=
    def auto_flush(bool = nil)
      self.auto_flush = bool unless bool.nil?
      auto_flush?
    end

    # @return [Bool] the current value of the `auto_flush` setting.
    # @see #auto_flush
    def auto_flush?
      @auto_flush
    end

    # Enable the {#auto_flush} feature for the current flow.
    #
    # @return [true]
    # @see #auto_flush
    def auto_flush!
      self.auto_flush = true
    end

    # @param bool [Bool] `true` to cause buffering Buffers to write their added
    #   messages and fields to the flow as soon as they are logged, `false` to
    #   write the whole event only on an explicit call to {Buffer#flush}.
    def auto_flush=(bool)
      @auto_flush = !!bool
    end

    # Close the log adapter if supported. This might be a no-op if the adapter
    # does not support closing. This method blocks if the flow is
    # {#synchronous?}.
    #
    # Any error raised by the adapter when closing it is logged to the
    # {#error_flow}. If the current flow is {#synchronous?}, the error is
    # re-raised.
    #
    # @return [true]
    def close
      @executor.post do
        begin
          @adapter.close
        rescue Exception => exception
          log_error("close failed for adapter #{adapter.inspect}", exception)
          raise unless exception.is_a?(StandardError)
          raise if synchronous?
        end
      end
    end

    # Get or set the encoder for the log {#adapter}. If this value is not
    # explicitly defined, it defaults to the #{adapter}'s default encoder.
    #
    # @param encoder_spec (see Rackstash::Encoder.build)
    # @param encoder_args (see Rackstash::Encoder.build)
    # @param block (see Rackstash::Encoder.build)
    # @raise [TypeError] if the given `encoder` does not respond to the `encode`
    #   method
    # @return [#encode] the newly set encoder (if given) or the currently
    #   defined one
    # @see #encoder=
    def encoder(encoder_spec = nil, *encoder_args, &block)
      return @encoder if encoder_spec.nil?
      @encoder = Rackstash::Encoder.build(encoder_spec, *encoder_args, &block)
    end

    # Set the encoder for the log {#adapter}. You can use any object which
    # responds to the `encode` method.
    #
    # @param encoder [#encode] the encoder to use for the log {#adapter}.
    # @raise [TypeError] if the given `encoder` does not respond to the `encode`
    #   method
    # @return [#encode] the new `encoder`
    def encoder=(encoder)
      @encoder = Rackstash::Encoder.build(encoder)
    end

    # Get or set a separate {Flow} which is used by this flow to write details
    # about any unexpected errors during interaction with the {#adapter}. If no
    # explicit value is set here, we use {Rackstash.error_flow} by default.
    #
    # @param error_flow [Flow, nil] if given, set the separate error flow to
    #   this object
    # @return [Rackstash::Flow] the newly set error flow (if given) or the
    #   currently defined one
    # @see #error_flow=
    def error_flow(error_flow = nil)
      return @error_flow || Rackstash.error_flow if error_flow.nil?
      self.error_flow = error_flow
      @error_flow
    end

    # Set a separate {Flow} which is used by this flow to write details
    # about any unexpected errors during interaction with the {#adapter}.
    #
    # If the given object is not already a {Flow}, we will wrap in into one.
    # This allows you to also give an adapter or just a plain log target which
    # can be wrapped in an adapter.
    #
    # When setting the `error_flow` to nil, we reset any custom `error_flow` on
    # this current Flow and will use the global {Rackstash.error_flow} to log
    # any errors.
    #
    # @param error_flow [Flow, Adapter, Object, nil] the separate error flow or
    #   `nil` to unset the custom error_flow and to use the global
    #   {Rackstash.error_flow} again
    # @return [Rackstash::Flow] the newly set error_flow
    def error_flow=(error_flow)
      unless error_flow.nil? || error_flow.is_a?(Rackstash::Flow)
        error_flow = Flow.new(error_flow)
      end

      @error_flow = error_flow
    end

    # (see FilterChain#insert_after)
    def filter_after(index, *filter, &block)
      @filter_chain.insert_after(index, *filter, &block)
      self
    end

    # (see FilterChain#append)
    def filter_append(*filter, &block)
      @filter_chain.append(*filter, &block)
      self
    end
    alias filter filter_append

    # (see FilterChain#delete)
    def filter_delete(index)
      @filter_chain.delete(index)
    end

    # (see FilterChain#insert_before)
    def filter_before(index, *filter, &block)
      @filter_chain.insert_before(index, *filter, &block)
      self
    end

    # (see FilterChain#unshift)
    def filter_unshift(*filter, &block)
      @filter_chain.unshift(*filter, &block)
      self
    end
    alias filter_prepend filter_unshift

    # Return the current value of the {#synchronous} flag.
    #
    # When set to `true`, we will block on writing events until it was either
    # written to the adapter or an error occured (which will be raised to the
    # caller after being logged to the {#error_flow}).
    #
    # By default (or when explicitly setting the `synchronous` attribute to
    # `false`), we write events asynchronously. Here, we return to the caller
    # immediately on {#write}. Any errors occuring during logging will be logged
    # to the {#error_flow} but will not be re-raised to the caller.
    #
    # @return [Bool] return the current value of the {#synchronous} flag
    def synchronous?
      @synchronous
    end

    # Re-open the log adapter if supported. This might be a no-op if the adapter
    # does not support reopening. This method blocks if the flow is
    # {#synchronous?}.
    #
    # Any error raised by the adapter when reopening it is logged to the
    # {#error_flow}. If the current flow is {#synchronous?}, the error is
    # re-raised.
    #
    # @return [true]
    def reopen
      @executor.post do
        begin
          @adapter.reopen
        rescue Exception => exception
          log_error("reopen failed for adapter #{adapter.inspect}", exception)
          raise unless exception.is_a?(StandardError)
          raise if synchronous?
        end
      end
    end

    # Filter, encode and write the given `event` to the configured {#adapter}.
    # The given `event` is updated in-place by the filters and encoder of the
    # flow and should not be re-used afterwards anymore.
    #
    # 1. At first, we filter the event with the defined {#filter_chain} in their
    #    given order. If any of the filters returns `false`, the writing will be
    #    aborted. No further filters will be applied and the event will not be
    #    written to the adapter. See {FilterChain#call} for details.
    # 2. We encode the event to a format suitable for the adapter using the
    #    configured {#encoder}.
    # 3. Finally, the encoded event will be passed to the {#adapter} to be sent
    #    to the actual log target, e.g. a file or an external log receiver.
    #
    # Any error raised by a filter, the encoder, or the adapter when writing is
    # logged to the {#error_flow}. If the current flow is {#synchronous?}, the
    # error is re-raised.
    #
    # @param event [Hash] an event hash
    # @return [Boolean] `true` if the event was written to the adapter, `false`
    #   otherwise
    def write(event)
      @executor.post do
        begin
          # Silently abort writing if any filter (and thus the whole filter chain)
          # returned `false`.
          next false unless @filter_chain.call(event)
          @adapter.write @encoder.encode(event)
          true
        rescue Exception => exception
          log_error("write failed for adapter #{adapter.inspect}", exception, event)
          raise unless exception.is_a?(StandardError)
          raise if synchronous?
        end
      end
    end

    private

    def log_error(message, exception, event = nil)
      message = Rackstash::Message.new(message, severity: ERROR)

      error_event = {
        FIELD_ERROR => exception.class.name,
        FIELD_ERROR_MESSAGE => exception.message,
        FIELD_ERROR_TRACE => (exception.backtrace || []).join("\n"),

        FIELD_TAGS => [],
        FIELD_MESSAGE => [message],
        FIELD_TIMESTAMP => message.time
      }
      error_event['event'] = event unless event.nil?

      error_flow.write(error_event)
    rescue
      # At this place, writing to the error log has also failed. This is a bad
      # place to be in and there is very little we can sensibly do now.
      #
      # To aid in availability of the app using Rackstash, we swallow any
      # StandardErrors by default and just continue, hoping that things will
      # turn out to be okay in the end.
      raise unless exception.is_a?(StandardError)
      raise if synchronous?
    end
  end
end
