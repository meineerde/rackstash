# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/rack/middleware'

describe Rackstash::Rack::Middleware do
  let(:app) {
    lambda { |env|
      logger = env['rack.logger']

      logger.debug('Request started')
      logger.warn('Nothing to do...')

      env['process'].call(env) if env['process']

      # Raise a RuntimeError if a raise parameter was set in the request
      request = ::Rack::Request.new(env)
      raise request.params['raise'] if request.params['raise']

      [200, { 'Content-Type' => 'text/plain' }, ['Hello, World!']]
    }
  }

  let(:log) { [] }
  let(:logger) { Rackstash::Logger.new ->(event) { log << event } }

  let(:args) { {} }
  let(:stack) { described_class.new(app, logger, **args) }

  def get(path, opts = {})
    ::Rack::MockRequest.new(::Rack::Lint.new(stack)).get(path, opts)
  end

  it 'requires a logger' do
    # missing logger
    expect { described_class.new app }.to raise_error ArgumentError

    # unsupported logger
    expect { described_class.new app, ::Logger.new(STDOUT) }.to raise_error TypeError
    expect { described_class.new app, nil }.to raise_error TypeError
    expect { described_class.new app, STDOUT }.to raise_error TypeError
  end

  it 'sets Buffer#buffering' do
    args[:buffering] = :data
    get('/stuff')

    expect(log).to match [
      include('message' => "Request started\n", 'method' => 'GET', 'path' => '/stuff'),
      include('message' => "Nothing to do...\n", 'method' => 'GET', 'path' => '/stuff'),
      include('message' => '', 'status' => 200)
    ]
  end

  it 'creates a new log scope' do
    2.times do
      expect(logger).to receive(:push_buffer).ordered.and_call_original
      expect(logger).to receive(:pop_buffer).ordered.and_call_original
    end

    get('/foo')
    get('/bar')
  end

  it 'sets rack.logger environment variable' do
    called = false
    app = lambda do |env|
      called = true
      expect(env['rack.logger']).to equal logger
      [200, { 'Content-Type' => 'text/plain' }, ['Hello, World!']]
    end

    ::Rack::MockRequest.new(described_class.new(app, logger)).get('/')
    expect(called).to be true
  end

  it 'sets rackstash.logger environment variable' do
    called = false
    app = lambda do |env|
      called = true
      expect(env['rackstash.logger']).to equal logger
      [200, { 'Content-Type' => 'text/plain' }, ['Hello, World!']]
    end

    ::Rack::MockRequest.new(described_class.new(app, logger)).get('/')
    expect(called).to be true
  end

  it 'sets rack.errors environment variable' do
    called = false
    app = lambda do |env|
      called = true
      expect(env['rack.errors']).to be_instance_of Rackstash::Rack::Errors
      expect(env['rack.errors'].logger).to equal logger
      [200, { 'Content-Type' => 'text/plain' }, ['Hello, World!']]
    end

    ::Rack::MockRequest.new(described_class.new(app, logger)).get('/')
    expect(called).to be true
  end

  it 'logs basic request data' do
    get('/demo')

    expect(log.last).to match(
      'method' => 'GET',
      'path' => '/demo',
      'status' => 200,
      'duration' => be_a(Float).and(be > 0),
      'message' => "Request started\nNothing to do...\n",
      '@timestamp' => /\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d.\d{6}Z/,
      'tags' => []
    )
  end

  context 'with request_fields' do
    it 'logs additional request fields' do
      args[:request_fields] = lambda { |request|
        {
          'do' => request.request_method.downcase,
          :massive => -> { fullpath.upcase }
        }
      }
      get('/stuff')

      expect(log.last).to include(
        'do' => 'get',
        'massive' => '/STUFF',
        'path' => '/stuff',
        'method' => 'GET'
      )
    end
  end

  context 'with request_tags' do
    it 'logs additional tags' do
      args[:request_tags] = lambda { |request|
        [[:foo], request.fullpath.upcase[/\w+/]]
      }
      get('/stuff')

      expect(log.last).to include('tags' => ['foo', 'STUFF'])
    end
  end

  context 'with response fields' do
    it 'logs additional fields' do
      args[:response_fields] = {
        :content_type => ->(headers) { headers['Content-Type'] },
        'static' => 'value'
      }
      get('/stuff')

      expect(log.last).to include(
        'path' => '/stuff',
        'method' => 'GET',
        'content_type' => 'text/plain',
        'static' => 'value'
      )
    end

    it 'retains existing fields' do
      args[:response_fields] = { 'path' => 'foo' }
      get('/stuff')

      expect(log.last).to include 'path' => '/stuff'
    end
  end

  context 'with response_tags' do
    it 'logs additional tags' do
      args[:response_tags] = lambda { |headers|
        [[:foo], headers['Content-Type'][/\w+/]]
      }
      get('/stuff')

      expect(log.last).to include('tags' => ['foo', 'text'])
    end
  end

  describe 'on errors' do
    it 'logs errors' do
      expect { get('/error', params: { raise: 'Oh noes!' }) }
        .to raise_error(RuntimeError, 'Oh noes!')

      expect(log.last).to include(
        'error' => 'RuntimeError',
        'error_message' => 'Oh noes!',
        'error_trace' => %r{\A#{__FILE__}:24:in}
      )
    end

    it 'sets the status to 500' do
      expect { get('/error', params: { raise: 'bum' }) }.to raise_error('bum')
      expect(log.last).to include 'status' => 500
    end

    it 'always logs request params first' do
      expect { get('/error', params: { raise: 'bum' }) }.to raise_error('bum')
      expect(log.last).to include(
        'method' => 'GET',
        'path' => '/error?raise=bum'
      )
    end

    it 'handles errors on setting request_fields' do
      args[:request_fields] = lambda {
        {
          'foo' => 'bar',
          'error' => -> { raise 'kaputt' }
        }
      }

      expect { get('/normal') }.to raise_error('kaputt')
      expect(log.last).to include(
        'error' => 'RuntimeError',
        'error_message' => 'kaputt',
        'error_trace' => %r{\A#{__FILE__}:#{__LINE__ - 8}:in},

        # The message is empty since we never even called the app.
        'message' => '',
        'status' => 500
      )

      # None of the response fields are set if normalization fails
      expect(log.last).to_not include 'foo'
    end

    it 'handles errors on setting response_fields' do
      args[:response_fields] = lambda {
        {
          'foo' => 'bar',
          'error' => -> { raise 'kaputt' }
        }
      }

      expect { get('/normal') }.to raise_error('kaputt')
      expect(log.last).to include(
        'error' => 'RuntimeError',
        'error_message' => 'kaputt',
        'error_trace' => %r{\A#{__FILE__}:#{__LINE__ - 8}:in},
        # The app did its thing
        'message' => "Request started\nNothing to do...\n",
        # We explicitly override the logged status, even if the app returned a
        # successful response earlier
        'status' => 500
      )

      # None of the response fields are set if normalization fails
      expect(log.last).to_not include 'foo'
    end
  end
end
