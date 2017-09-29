# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

module Rackstash
  # Version information about Rackstash. We follow semantic versioning.
  module Version
    # MAJOR version. It is incremented after incompatible API changes
    MAJOR = 0
    # MINOR version. It is incremented after adding functionality in a
    # backwards-compatible manner
    MINOR = 2
    # PATCH version. It is incremented when making backwards-compatible
    # bug-fixes.
    PATCH = 0
    # PRERELEASE suffix. Set to a alphanumeric string on any pre-release
    # versions like beta or RC releases.
    PRERELEASE = 'dev'.freeze

    # The Rackstash version as a semver-compliant string
    # @see http://semver.org/
    STRING = begin
      base_version = [MAJOR, MINOR, PATCH].compact.join('.')
      release = [base_version, PRERELEASE].compact.join('-')
      release.freeze
    end

    # @return [Gem::Version] the version of the currently loaded Rackstash as
    #   a `Gem::Version`
    def self.gem_version
      Gem::Version.new STRING
    end

    # @return [String] the Rackstash version as a semver-compliant string
    def self.to_s
      STRING
    end
  end

  # The Rackstash version as a semver-compliant string
  # @see Version::STRING
  VERSION = Version::STRING
end
