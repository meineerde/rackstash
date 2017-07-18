# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'rackstash/filters/skip_event'

module Rackstash
  # Filters are part of a {Flow} where they can alter the log event before it is
  # passed to the encoder and finally to the adapter. With filters, you can add,
  # change or delete fields. Since each flow uses its own copy of a log event,
  # you can use a different set of filters per flow and can adapt the event
  # anyway you require.
  #
  # You can e.g. remove unenessary fields, anonymize logged IP addresses or
  # filter messages. In its `call` method, the passed event hash can be mutated
  # in any way. Since the event hash includes an array of {Message} objects in
  # `event["messages"]` which provide the original severity and timestamp of
  # each logged message, you can also retrospectively filter the logged messages.
  #
  # A filter can be any object responding to `call`, e.g. a Proc or a concrete
  # class inside this module.
  module Filters
  end
end
