# frozen_string_literal: true

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
    def initialize(adapter, encoder: nil, filters: [], &block)
      @adapter = Rackstash::Adapters[adapter]
      self.encoder(encoder || @adapter.default_encoder)
      @filter_chain = Rackstash::FilterChain.new(filters)

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
    def close
      @adapter.close
      nil
    rescue Exception => exception
      log_error("close failed for adapter #{adapter.inspect}", exception)
      raise unless exception.is_a?(StandardError)
    end

    # Get or set the encoder for the log {#adapter}. If this value is not
    # explicitly defined, it defaults to the #{adapter}'s default encoder.
    #
    # @param encoder [#encode, nil] if given, set the flow's encoder to this
    #   object
    # @raise [TypeError] if the given encoder does not respond to the `encode`
    #   method
    # @return [#encode] the new encoder if given or the currently defined one
    def encoder(encoder = nil)
      return @encoder if encoder.nil?

      raise TypeError, 'must provide an encoder' unless encoder.respond_to?(:encode)
      @encoder = encoder
    end

    # (see FilterChain#insert_after)
    def filter_after(index, filter = nil, &block)
      @filter_chain.insert_after(index, filter, &block)
      self
    end

    # (see FilterChain#append)
    def filter_append(filter = nil, &block)
      @filter_chain.append(filter, &block)
      self
    end
    alias filter filter_append

    # (see FilterChain#delete)
    def filter_delete(index)
      @filter_chain.delete(index)
    end

    # (see FilterChain#insert_before)
    def filter_before(index, filter = nil, &block)
      @filter_chain.insert_before(index, filter, &block)
      self
    end

    # (see FilterChain#unshift)
    def filter_prepend(filter = nil, &block)
      @filter_chain.unshift(filter, &block)
      self
    end
    alias filter_unshift filter_prepend

    # Re-open the log adapter if supported. This might be a no-op if the adapter
    # does not support reopening. This method is called by the logger's {Sink}.
    #
    # @return [nil]
    def reopen
      @adapter.reopen
      nil
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
    #    written to the adapter.
    # 2. After the filters, we normalize the `event["message"]` field. While the
    #    filters still had access to the array of {Message} objects for
    #    filtering, we now concatenate the raw messages as a single string to
    #    get the final event. The `event["message"]` field now contains a single
    #    `String` object.
    # 3. We encode the event to a format suitable for the adapter using the
    #    configured {#encoder}.
    # 4. Finally, the encoded event will be passed to the {#adapter} to be send
    #    to the actual log target, e.g. a file or an external log receiver.
    #
    # @api private
    #
    # @param event [Hash] an event hash
    # @return [Boolean] `true` if the event was written to the adapter, `false`
    #   otherwise
    # @see Sink#write
    def write(event)
      # Silently abort writing if any filter (and thus the while filter chain)
      # returns `false`.
      return false unless @filter_chain.call(event)

      event[FIELD_MESSAGE] =
        case event[FIELD_MESSAGE]
        when Array
          event[FIELD_MESSAGE].map!(&:to_s).join
        when nil
          ''
        else
          event[FIELD_MESSAGE].to_s
        end

      @adapter.write @encoder.encode(event)
      true
    rescue Exception => exception
      log_error("write failed for adapter #{adapter.inspect}", exception)
      exception.is_a?(StandardError) ? false : raise
    end

    private

    # TODO: use a fallback flow and send formatted logs there
    def log_error(message, exception)
      warn("#{message}: #{exception}")
    end
  end
end
