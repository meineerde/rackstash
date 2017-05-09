# Rackstash

[![Gem Version](https://badge.fury.io/rb/rackstash.svg)](https://rubygems.org/gems/rackstash)
[![Build Status](https://travis-ci.org/meineerde/rackstash.svg?branch=master)](http://travis-ci.org/meineerde/rackstash)
[![Coverage Status](https://coveralls.io/repos/github/meineerde/rackstash/badge.svg?branch=master)](https://coveralls.io/github/meineerde/rackstash?branch=master)

**Note: This gem is still work in progress. It is not yet usable and does not support any end-to-end logging. The good news is that we are working on that :)**

Rackstash is a Logger replacement for Ruby applications to allow flexible structured logging from request-based Ruby applications based on e.g [Rack](https://github.com/rack/rack), [Rails](http://rubyonrails.org/) or similar frameworks. It works best with a log receiver like [Logstash](https://www.elastic.co/products/logstash) or [Graylog](https://www.graylog.org).

Rackstash aims to provide a simple and clearly understood interface without too much magic. Being an infrastructure component of other apps, Rackstash aims to be extensible and adaptable towards novel use-cases.

This is the framework-agnostic base package with only minimal dependencies. There are several packages for framework-specifc integrations. If you use those, check out these gems:

| Framework     | Gem |
| ------------- | --- |
| Ruby on Rails | [rackstash-rails](https://github.com/meineerde/rackstash-rails) |
| Hanami        | [rackstash-hanami](https://github.com/meineerde/rackstash-hanami) |

## Table of Contents

* [Why Rackstash?](#why-rackstash)
* [Installation](#installation)
* [Usage](#usage)
  - [Synopsis](#synopsis)

## Why Rackstash

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rackstash'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rackstash

## Usage

* [Code Documentation](http://www.rubydoc.info/github/meineerde/rackstash/master)

### Synopis

```ruby
require 'rackstash'

# Create a new logger which writes its logs to the log/application.log file
# The logger will write logs in Logstash's JSON format
logger = Rackstash::Logger.new('log/application.log')

# With this buffer, you can log single messages to the logfile, one after
# another. This works similar to a plain old Ruby logger. We support all
# methods you'd expect from a logger.
logger.info 'Hello World'

# You can create a new buffer using the with_buffer method. All log messages
# you send within the block will be appended to the buffer and will be flushed
# as a single log event only when you leave the block again.
#
# On each buffer, you can set (nested) fields and tags. These will be included
# in the log event written to the log file.
logger.with_buffer do
  logger.tag 'my_application'
  logger['server'] = Socket.gethostname
  
  logger.debug 'Starting request...'
  logger.info  'Performing some work...'
  logger.debug 'Done'
end
```

With the default JSON codec (you can chose another, see below) the emitted log events from the example above will look like this:

```json
{"@version":"1","@timestamp":"2016-12-07T13:37:13.370Z","message":"Hello World","tags":[]}
{"server":"www.example.com","@version":"1","@timestamp":"2016-12-07T13:37:13.420Z","message":"Starting request...\nPerforming some work...\nDone","tags":["my_application"]}
```

As you can see, we have written only two log events to our log file. The second event contains all three logged messages in the `"message"` field.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meineerde/rackstash. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

