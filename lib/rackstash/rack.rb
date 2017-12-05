# frozen_string_literal: true
# Copyright 2016 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash'
require 'rack'

module Rackstash
  # This module contains the integration classes into
  # [Rack](https://github.com/rack/rack), the generic webserver interface for
  # Ruby frameworks.
  #
  # Here, we provide a very basic integration. You can use it as a building
  # block for more specific integrations into frameworks like Hanami, Rails, or
  # Sinatra.
  module Rack
  end
end

require 'rackstash/rack/middleware'
