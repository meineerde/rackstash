# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

if ENV['COVERAGE'].to_s == 'true'
  require 'simplecov'

  if ENV['CI'] == 'true'
    require 'coveralls'
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
        SimpleCov::Formatter::HTMLFormatter,
        Coveralls::SimpleCov::Formatter
    ]
  else
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  end

  SimpleCov.start do
    project_name 'Rackstash'
    add_filter '/spec/'
  end

  # Load `rackstash/version.rb` again to get proper coverage data. This file is
  # already loaded by bundler before SimpleCov starts during evaluation of the
  # the `rackstash.gemspec` file
  begin
    warn_level, $VERBOSE = $VERBOSE, nil
    load File.expand_path('../lib/rackstash/version.rb', __dir__)
  ensure
    $VERBOSE = warn_level
  end
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'rackstash'

RSpec.configure do |config|
  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    # This option should be set when all dependencies are being loaded
    # before a spec run, as is the case in a typical spec helper. It will
    # cause any verifying double instantiation for a class that does not
    # exist to raise, protecting against incorrectly spelt names.
    mocks.verify_doubled_constant_names = true
  end
end
