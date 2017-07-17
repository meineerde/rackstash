# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/sink'

describe Rackstash::Sink do
  let(:targets) { [] }
  let(:sink) { Rackstash::Sink.new(targets) }

  describe '#initialize' do
    it 'accepts an array with targets' do
      expect(targets).to receive(:to_ary).once.and_call_original
      expect(sink.targets).to equal targets
    end

    it 'wraps a single target into an array' do
      target = Object.new
      expect(Rackstash::Sink.new(target).targets).to eql [target]
    end
  end

  describe '#flush' do
    it 'flushes the buffer to all targets' do
      buffer = double('buffer')

      target = double('target')
      targets << target

      expect(target).to receive(:flush).with(buffer)
      sink.flush(buffer)
    end
  end
end
