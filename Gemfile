# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

source 'https://rubygems.org'

gemspec name: 'rackstash'

gem 'rake'

group :test do
  gem 'rspec', '~> 3.0'
  gem 'coveralls', '~> 0.8.20'

  gem 'rack', ENV['RACK_VERSION'] ? "~> #{ENV['RACK_VERSION']}" : nil
end

group :doc do
  gem 'yard', '~> 0.9'
end

if RUBY_ENGINE == 'truffleruby'
  # Truffleruby requires a prerelease of concurrent-ruby currently
  gem 'concurrent-ruby', '>= 1.1.0.pre2'
end
