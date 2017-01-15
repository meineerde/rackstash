# coding: utf-8
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rackstash/version'

Gem::Specification.new do |spec|
  spec.name          = 'rackstash'
  spec.version       = Rackstash::VERSION
  spec.authors       = ['Holger Just']

  spec.summary       = 'Easy structured logging for Ruby applications'
  spec.description   = <<-TXT.gsub(/\s+|\n/, ' ').strip
    A drop-in replacement for Ruby's Logger to allow flexible structured logging
    for request-based applications built on e.g Rack, Rails or similar
    frameworks. It works best with a log receiver like Logstash or Graylog.
  TXT
  spec.homepage      = 'https://github.com/meineerde/rackstash'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.1.0'

  files = `git ls-files -z`.split("\x0")
  spec.files         = files.reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
