# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

source 'https://rubygems.org'

gemspec name: 'rackstash'

group :test do
  gem 'rack', ENV['RACK_VERSION'] ? "~> #{ENV['RACK_VERSION']}" : nil
end

if RUBY_ENGINE == 'truffleruby'
  # Truffleruby requires a prerelease of concurrent-ruby currently
  gem 'concurrent-ruby', '>= 1.1.0.pre2'
end
