# frozen_string_literal: true
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/version'

describe 'Rackstash::Version' do
  it 'has a version number' do
    expect(Rackstash::Version::STRING).to be_a String
    expect(Rackstash::Version::STRING).to equal Rackstash::Version.to_s
  end

  it 'exposes the version as Rackstash::VERSION' do
    expect(Rackstash::VERSION).to equal Rackstash::Version::STRING
  end

  it 'exposes a gem_version method' do
    expect(Rackstash::Version.gem_version).to be_a Gem::Version
    expect(Rackstash::Version.gem_version.to_s.gsub('.pre.', '-'))
      .to eql Rackstash::VERSION
  end
end
