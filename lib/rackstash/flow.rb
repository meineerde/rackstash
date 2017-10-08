# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/adapters'
require 'rackstash/encoders'
require 'rackstash/filters'
require 'rackstash/filter_chain'

module Rackstash
  # A Flow is responsible for taking a raw log event (originally corresponding
  # to a single {Buffer}), transforming it and finally sending it to an adapte
  # for persistence. A Flow instance is normally tied to a {Flows} list which in
  # turn belongs to a log {Sink}.
  #
  # In order to transform and persist log events, a Flow uses several
  # components:
  #
  # * Any number of {Filters} (zero or more). The filters can change the log
  #   event before it is passed to the adapter by adding, changing, or removing
  #   fields. The filters also have access to the array of {Message} objects in
  #   `event["messages"]` which provide the original severity and timestamp of
  #   each message.
  # * An `Encoder` which is responsible to transform the filtered event into a
  #   format suitable for the final log adapter. Most of the time, the encoder
  #   generates a String but can also produce other formats. Be sure to chose
  #   an encoder which matches the adapter's expectations. Usually, this is one
  #   of the {Encoders}.
  # * And finally the log `Adapter` which is responsible to send the encoded log
  #   event to an external log target, e.g. a file or an external log receiver.
  #   When setting up the flow, you can either provide an existing adapter
  #   object or provide an object which can be wrapped in an adapter. See
  #   {Adapters} for a list of pre-defined log adapters.
  #
  # You can build a Flow using a simple DSL:
  #
  #     flow = Rackstash::Flow.new(STDOUT) do
  #       encoder Rackstash::Encoders::JSON.new
  #
  #       # Anonymize IPs in the remote_ip field.
  #       filter Rackstash::Filters::AnonymizeIPMask.new('remote_ip')
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
  #     end
  #
  #     # Write an event. This is normally done by the responsible Rackstash::Sink
  #     flow.write(an_event)
  #
  # The event which eventually gets written to the flow is created by the {Sink}
  # of a {Logger}.
  class Flow
    # @return [Adapters::Adapter] the log adapter
    attr_reader :adapter

    # @return [FilterChain] the mutable filter chain.
    attr_reader :filter_chain

    # @param adapter [Adapters::Adapter, Object] an adapter or an object which
    #   can be wrapped in an adapter. See {Adapters.[]}
    # @param encoder [#encode] an encoder, usually one of the {Encoders}. If
    #   this is not given, the adapter's default_encoder will be used.
    # @param filters [Array<#call>] an array of filters. Can be one of the
    #   pre-defined {Filters}, a `Proc`, or any other object which responds to
    #   `call`.
    # @yieldparam flow [self] if the given block accepts an argument, we yield
    #   `self` as a parameter, else, the block is directly executed in the
    #   context of `self`.
    def initialize(adapter, encoder: nil, filters: [], error_flow: nil, &block)
      @adapter = Rackstash::Adapters[adapter]
      self.encoder = encoder || @adapter.default_encoder
      @filter_chain = Rackstash::FilterChain.new(filters)
      self.error_flow = error_flow

      if block_given?
        if block.arity == 0
          instance_eval(&block)
        else
          yield self
        end
      end
    end

    # Close the log adapter if supported. This might be a no-op if the adapter
    # does not support closing. This method is called by the logger's {Sink}.
    #
    # @return [nil]
    def close!
      @adapter.close
      nil
    end

    # (see #close!)
    #
    # Any error raised by the adapter when closing it is logged to the
    # {#error_flow} and then swallowed. Grave exceptions (i.e. all those which
    # do not derive from `StandardError`) are logged and then re-raised.
    def close
      close!
    rescue Exception => exception
      log_error("close failed for adapter #{adapter.inspect}", exception)
      raise unless exception.is_a?(StandardError)
    end

    # Get or set the encoder for the log {#adapter}. If this value is not
    # explicitly defined, it defaults to the #{adapter}'s default encoder.
    #
    # @param encoder [#encode, nil] if given, set the flow's encoder to this
    #   object
    # @raise [TypeError] if the given `encoder` does not respond to the `encode`
    #   method
    # @return [#encode] the newly set encoder (if given) or the currently
    #   defined one
    # @see #encoder=
    def encoder(encoder = nil)
      return @encoder if encoder.nil?
      self.encoder = encoder
    end

    # Set the encoder for the log {#adapter}. You can use any object which
    # responds to the `encode` method.
    #
    # @param encoder [#encode] the encoder to use for the log {#adapter}.
    # @raise [TypeError] if the given `encoder` does not respond to the `encode`
    #   method
    # @return [#encode] the new `encoder`
    def encoder=(encoder)
      raise TypeError, 'must provide an encoder' unless encoder.respond_to?(:encode)
      @encoder = encoder
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
    # @param error_flow [Flow, Adapter, Object, nil] the separate error flow or
    #   `nil` to unset the custom error_flow ant to use the global
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

    # Re-open the log adapter if supported. This might be a no-op if the adapter
    # does not support reopening. This method is called by the logger's {Sink}.
    #
    # @return [nil]
    def reopen!
      @adapter.reopen
      nil
    end

    # (see #reopen!)
    #
    # Any error raised by the adapter when reopening it is logged to the
    # {#error_flow} and then swallowed. Grave exceptions (i.e. all those which
    # do not derive from `StandardError`) are logged and then re-raised.
    def reopen
      reopen!
    rescue Exception => exception
      log_error("reopen failed for adapter #{adapter.inspect}", exception)
      raise unless exception.is_a?(StandardError)
    end

    # Filter, encode and write the given `event` to the configured {#adapter}.
    # This method is called by the logger's {Sink} to write a log event. The
    # given `event` is updated in-place and should not be re-used afterwards
    # anymore.
    #
    # 1. At first, we filter the event with the defined filters in their given
    #    order. If any of the filters returns `false`, the writing will be
    #    aborted. No further filters will be applied and the event will not be
    #    written to the adapter. See {FilterChain#call} for details.
    # 2. We encode the event to a format suitable for the adapter using the
    #    configured {#encoder}.
    # 3. Finally, the encoded event will be passed to the {#adapter} to be send
    #    to the actual log target, e.g. a file or an external log receiver.
    #
    # @param event [Hash] an event hash
    # @return [Boolean] `true` if the event was written to the adapter, `false`
    #   otherwise
    # @see Sink#write
    def write!(event)
      # Silently abort writing if any filter (and thus the while filter chain)
      # returns `false`.
      return false unless @filter_chain.call(event)
      @adapter.write @encoder.encode(event)
      true
    end

    # (see #write!)
    #
    # Any error raised by the adapter when writing to it is logged to the
    # {#error_flow} and then swallowed. Grave exceptions (i.e. all those which
    # do not derive from `StandardError`) are logged and then re-raised.
    def write(event)
      write!(event)
    rescue Exception => exception
      log_error("write failed for adapter #{adapter.inspect}", exception)
      exception.is_a?(StandardError) ? false : raise
    end

    private

    def log_error(message, exception)
      message = Rackstash::Message.new(message, severity: ERROR)

      error_event = {
        FIELD_ERROR => exception.class.name,
        FIELD_ERROR_MESSAGE => exception.message,
        FIELD_ERROR_TRACE => (exception.backtrace || []).join("\n"),

        FIELD_TAGS => [],
        FIELD_MESSAGE => [message],
        FIELD_TIMESTAMP => message.time
      }
      error_flow.write!(error_event)
    rescue
      # At this place, writing to the error log has also failed. This is a bad
      # place to be in and there is very little we can sensibly do now.
      #
      # To aid in availability of the app using Rackstash, we swallow any
      # StandardErrors here and just continue, hoping that things will turn out
      # to be okay in the end.
    end
  end
end
