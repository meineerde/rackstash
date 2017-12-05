# frozen_string_literal: true
# Copyright 2016 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rack'

require 'rackstash/helpers/time'
require 'rackstash/rack/errors'

module Rackstash
  module Rack
    # The Rack logging middleware provides a way to log structured data for each
    # request passing through to the Rack application.
    #
    # The middleware works as a combination of the `::Rack::Logger` and
    # especially the `::Rack::CommonLogger` middlewares shipped with Rack. For
    # each request, we open a new log environment by pushing a new {Buffer} to
    # the current Thread's stack. All log messages as well as any fields logged
    # to the {#logger} will be added to this buffer. After the request has
    # ended, we pop the buffer from the stack again and flush all logged data to
    # the configured log flows of the given {Rackstash::Logger} object.
    #
    # By default, we log the following fields about each request:
    #
    #   * `"method"` - the HTTP verb, e.g. `"GET"`, `"POST"`, or "`PUT`"
    #   * `"path"` - the request path, e.g. `"/desserts/cake?cream=1&cheese=0"`
    #   * `"status"` - the numeric HTTP response code, e.g. `200`, or `500`
    #   * `"duration"` - the duration in seconds with fractions between first
    #     receiving the request and its eventual delivery to the client by the
    #     application server, e.g. `0.295372`. This time equals the duration
    #     logged by the `::Rack::CommonLogger` middleware which ships with Rack.
    #
    # In addition to that, we can also log additional data from the request or
    # the response. For that, you can set additional (optionally lazy-evaluated)
    # fields and tags.
    #
    # In a Rack builder, you can define the middleware as follows
    #
    #     # First, create the logger however you like. You can use multiple
    #     # flows, add filters, ...
    #     logger = Rackstash::Logger.new(STDOUT)
    #
    #     use Rackstash::Rack::Middleware,
    #       logger,
    #       buffering: :full,
    #       request_fields: {
    #         'user_agent' => ->(request) { request.headers['user-agent'] },
    #         'remote_ip' => ->(request) { request.ip },
    #         'server' => Socket.gethostname
    #       },
    #       request_tags: ['rack', ->(request) { request.scheme }],
    #       response_fields: ->(headers) {
    #         { 'location' => headers['location'] }
    #       },
    #       response_tags: ->(headers) { ["cache_status_#{headers[x-rack-cache]}"] }
    #
    # Here, we instruct the middleware to log each request to the provided
    # `logger`. For each request, we will by default emit a single log event to
    # each flow of the logger. You can customize this by setting the `buffering`
    # argument. See {Buffer#buffering} for a description of the values. During
    # development, it might be useful to set this to `:data` to emit log events
    # directly for each logged message instead of only once after the request
    # was finished.
    #
    # In the log event(s) emitted for the request, we add the default fields
    # described above, plus some data extracted from the HTTP request data. For
    # dynamic values, we can use the `::Rack::Request` object for the current
    # request. In our example above, we add the user agent header of the
    # client's webbrowser and the client's IP address. We also set a `"server"`
    # field containing the server's hostname. We are also setting some tags, in
    # this case we set the static tag `"rack"` and a tag for the current
    # request's scheme. Usually, this is either `"http"` or `"https"`.
    #
    # For the response, we have the same flexibility. Here, we can use the hash
    # containing the response headers to set additional fields or tags to the
    # log buffer. In our example above, we add the value of the `Location`
    # header of the response as a field and add a tag based on the status of the
    # Rack::Cache middleware our app might be using.
    #
    # Note that all fields set by the middleware are deep-merged into the
    # Buffer's current fields using {Fields::Hash#deep_merge!}. All existing
    # fields set by the application will be preserved and are not overwritten.
    #
    # In case there is an unhandled exception during request processing in the
    # Rack application or any lower middleware, we log this error using
    # {Rackstash::Logger#add_exception}. The emitted event will still contain
    # all added request fields and tags as well as the `"status"` field (set to
    # `500`) and the duration of the request so far.
    class Middleware
      include Rackstash::Helpers::Time

      # @return [Rackstash::Logger] the Rackstash logger used to log the
      #   request details
      attr_reader :logger

      # @return [Hash<#to_s => Object>, Proc] a `Hash` specifying fields to be
      #   logged for each request. The fields will be added to the log {Buffer}
      #   before the request is passed to the Rack application. You can either
      #   give a literal `Hash` object or a `Proc` which returns such a `Hash`.
      #
      #   When including `Proc`s, they are evaluated with the `Rack::Request`
      #   object as a scope. See {Rackstash::Fields::Hash#deep_merge!}.
      attr_accessor :request_fields

      # @return [Array<#to_s, Proc>, Proc] Strings to add as tags to the logged
      #   event. The fields will be added to the log {Buffer} before the request
      #   is passed to the Rack application. You can either give (`Array`s of)
      #   `String`s here or `Proc`s which return a `String` or an `Array` of
      #   `String`s when called. When including `Proc`s, they are evaluated with
      #   the `Rack::Request` object as a scope.
      #   See {Rackstash::Fields::Tags#merge!}.
      attr_accessor :request_tags

      # @return [Hash<#to_s => Object>, Proc] a `Hash` specifying fields to be
      #   logged for each response. The fields will be added to the log {Buffer}
      #   after the response was successfully returned by the Rack application
      #   and no unhandled exception was thrown. You can either give a literal
      #   `Hash` object or a `Proc` which returns such a `Hash`.
      #
      #   When including `Proc`s, they are evaluated with the response headers
      #   in a `::Rack::Utils::HeaderHash` object as a scope. See
      #   {Rackstash::Fields::Hash#deep_merge!}.
      attr_accessor :response_fields

      # @return [Array<#to_s, Proc>, Proc] Strings to add as tags to the logged
      #   event for each response.  The fields will be added to the log {Buffer}
      #   after the response was successfully returned by the Rack application
      #   and no unhandled exception was thrown. You can either give (`Array`s
      #   of) `String`s here or `Proc`s which return a `String` or an `Array` of
      #   Strings when called. When including `Proc`s, they are evaluated with
      #   the response headers in a `::Rack::Utils::HeaderHash` object as a
      #   scope.
      #   See {Rackstash::Fields::Tags#merge!}.
      attr_accessor :response_tags

      # @param app [#call] A Rack application according to the Rack
      #   specification. A Rack application is a Ruby object (usually not a
      #   class) that responds to `call`. It takes exactly one argument, the
      #   `environment` and returns an `Array` of exactly three values: the
      #   `status`, the `headers`, and the `body`.
      # @param logger [Rackstash::Logger] the {Rackstash::Logger} instance to
      #   log each request to
      # @param buffering [Symbol, Boolean] define how the created {Buffer}s
      #   should buffer stored data. See {Buffer#buffering} for details.
      # @param request_fields [Hash<#to_s, => Proc, Object>, Fields::Hash, Proc]
      #   Additional fields to merge into the emitted log event before
      #   processing the request. If the object itself or any of its hash values
      #   is a `Proc`, it will get called, passing the `Rack::Request` object
      #   for the current request as an argument, and its result is used
      #   instead.
      # @param request_tags [Array<#to_s, Proc>, Set<#to_s, Proc>, Proc] an
      #   `Array` specifying default tags for each request. You can either give
      #   a literal `Array` containing Strings or a `Proc` which returns such an
      #   `Array`. If the object itself or any of its values is a `Proc`, it is
      #   called, passing the `Rack::Request` object for the current request
      #   as an argument, and its result is used instead.
      # @param response_fields [Hash<#to_s, => Proc, Object>, Fields::Hash, Proc]
      #   Additional fields to merge into the emitted log event after processing
      #   the request and sending the complete response. If the object itself
      #   or any of its hash values is a `Proc`, it will get called, passing
      #   the `Hash` of response headers of the current response as an argument,
      #   and its result is used instead.
      # @param response_tags [Array<#to_s, Proc>, Set<#to_s, Proc>, Proc] an
      #   `Array` specifying default tags for each returned response. You can
      #   either give a literal `Array` containing Strings or a `Proc` which
      #   returns such an `Array`. If the object itself or any of its values is
      #   a `Proc`, it is called, passing the `Hash` of response headers of the
      #   current response as an argument, and its result is used instead.
      # @raise [TypeError] if the passed `logger` is not a {Rackstash::Logger}
      def initialize(
        app, logger, buffering: :full,
        request_fields: nil, request_tags: nil,
        response_fields: nil, response_tags: nil
      )
        unless logger.is_a?(Rackstash::Logger)
          raise TypeError, 'logger must be a Rackstash::Logger'
        end

        @app = app
        @logger = logger
        @buffering = buffering

        @request_fields = request_fields
        @response_fields = response_fields
        @request_tags = request_tags
        @response_tags = response_tags
      end

      # Push a new {Buffer} to the stack and run the Rack app for the request.
      # All information logged by the Rack app during the request will be added
      # to this {Buffer} which will be flushed after the request returned.
      #
      # @param env [Hash] the Rack environment Hash
      # @return [Array] the three-element array containing the numeric response
      #   status, the response headers and the body according to the Rack
      #   specification.
      def call(env)
        began_at = clock_time
        env['rackstash.logger'.freeze] = @logger
        env['rack.logger'.freeze] = @logger
        env['rack.errors'.freeze] = Rackstash::Rack::Errors.new(@logger)

        @logger.push_buffer(buffering: @buffering, allow_silent: true)
        begin
          @logger.timestamp
          on_request(env)

          response = @app.call(env)
        rescue Exception => exception
          buffer = @logger.pop_buffer
          if buffer
            begin
              on_error(buffer, env, began_at, exception)
            ensure
              buffer.flush
            end
          end
          raise
        end

        buffer = @logger.pop_buffer
        on_response(buffer, env, began_at, response) if buffer

        response
      end

      private

      # @param env [Hash] The Rack environment
      # @return [void]
      def on_request(env)
        log_request(env)
      end

      # (see #on_request)
      def log_request(env)
        request = ::Rack::Request.new(env)

        @logger.fields[FIELD_METHOD] = request.request_method
        @logger.fields[FIELD_PATH] = request.fullpath

        @logger.fields.deep_merge!(
          @request_fields,
          scope: request,
          force: false
        ) unless @request_fields.nil?
        @logger.tag(@request_tags, scope: request) unless @request_tags.nil?
      end

      # @param buffer [Rackstash::Buffer] the log {Buffer} which was captured
      #   the logs during the request in the lower layers.
      # @param env [Hash] the Rack environment
      # @param began_at [Float] a timestamp denoting the start of the request.
      #   It can be used to get a request duration by subtracting it from
      #   {#clock_time}.
      # @param response [Array] a three-element array containing the Rack
      #   response. It consists of the numeric `status` code, a Hash containing
      #   the response `headers`, and the response `body`.
      #
      # @return [void]
      def on_response(buffer, env, began_at, response)
        response[1] = ::Rack::Utils::HeaderHash.new(response[1])
        response[2] = ::Rack::BodyProxy.new(response[2]) do
          begin
            log_response(buffer, env, began_at, response[0], response[1])
          rescue Exception => exception
            on_error(buffer, env, began_at, exception)
            raise
          ensure
            buffer.flush
          end
        end

        response
      end

      # Log data from the response to the buffer for the request.
      #
      # Note that we are directly writing to the `buffer` here, not the
      # `@logger`. This is necessary because `log_response` is called very late
      # during response processing by the application server where the buffer is
      # already poped from the stack.
      #
      # @param buffer (see #on_response)
      # @param env (see #on_response)
      # @param began_at (see #on_response)
      # @param status [Integer] the numeric response status
      # @param headers [::Rack::Utils::HeaderHash] the response headers
      #
      # @return [void]
      def log_response(buffer, env, began_at, status, headers)
        fields = {
          FIELD_STATUS => ::Rack::Utils.status_code(status),
          FIELD_DURATION => (clock_time - began_at).round(ISO8601_PRECISION)
        }
        buffer.fields.merge!(fields, force: false)

        buffer.fields.deep_merge!(
          @response_fields,
          scope: headers,
          force: false
        ) unless @response_fields.nil?
        buffer.tag(@response_tags, scope: headers) unless @response_tags.nil?
      end

      # @param buffer [Rackstash::Buffer] the log {Buffer} which was captured
      #   the logs during the request in the lower layers.
      # @param env [Hash] The Rack environment
      # @param began_at [Float] a timestamp denoting the start of the request.
      #   It can be used to get a request duration by subtracting it from
      #   {#clock_time}.
      # @param exception [Exception] a rescued exception
      #
      # @return [void]
      def on_error(buffer, env, began_at, exception)
        log_error(buffer, env, began_at, exception)
      end

      # (see #on_error)
      def log_error(buffer, env, began_at, exception)
        buffer.add_exception(exception, force: false)

        # Always set the status to 500, even if the app returned a successful
        # status. This is necessary to reflect the true status upsteam in case
        # there was an exception on adding request fields
        buffer.fields[FIELD_STATUS] = 500
        buffer.fields.set(FIELD_DURATION, force: false) {
          (clock_time - began_at).round(ISO8601_PRECISION)
        }
      end
    end
  end
end
