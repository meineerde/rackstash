# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

source 'https://rubygems.org'

gemspec name: 'rackstash'

group :test do
  if ENV['RACK_VERSION']
    gem 'rack', "~> #{ENV['RACK_VERSION']}"
  else
    gem 'rack'
  end
end
