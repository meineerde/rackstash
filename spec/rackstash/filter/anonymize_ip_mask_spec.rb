# frozen_string_literal: true
#
# Copyright 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter/anonymize_ip_mask'

describe Rackstash::Filter::AnonymizeIPMask do
  let(:event) {
    {
      'ipv4' => '10.123.42.65',
      'ipv6' => '2400:cb00:2048:1::6810:1460',
      'ipv6_mapped' => '::FFFF:192.168.42.65',
      'ipv6_compat' => '::10.123.42.65',
      'invalid' => 'invalid',
      'array' => ['10.123.42.65', 123, 'foobar', '2400:cb00:2048:1::6810:1460']
    }
  }

  let(:filter_spec) { {} }
  let(:ipv4_mask) { 8 }
  let(:ipv6_mask) { 80 }
  let(:filter) {
    described_class.new(
      filter_spec,
      ipv4_mask: ipv4_mask,
      ipv6_mask: ipv6_mask
    )
  }

  it 'masks IPv4 addresses' do
    filter_spec['ipv4'] = 'anonymized'
    filter.call(event)

    expect(event).to include(
      'ipv4' => '10.123.42.65',
      'anonymized' => '10.123.42.0'
    )
  end

  it 'masks IPv6 addresses' do
    filter_spec['ipv6'] = 'anonymized'
    filter.call(event)

    expect(event).to include(
      'ipv6' => '2400:cb00:2048:1::6810:1460',
      'anonymized' => '2400:cb00:2048::'
    )
  end

  it 'masks IPv4-mapped IPv6 addresses' do
    filter_spec['ipv6_mapped'] = 'anonymized'
    filter.call(event)

    expect(event).to include(
      'ipv6_mapped' => '::FFFF:192.168.42.65',
      'anonymized' => '::ffff:192.168.42.0'
    )
  end

  it 'masks IPv4-compatible IPv6 addresses' do
    filter_spec['ipv6_compat'] = 'anonymized'
    filter.call(event)

    expect(event).to include(
      'ipv6_compat' => '::10.123.42.65',
      'anonymized' => '::10.123.42.0'
    )
  end

  it 'retains invalid values' do
    filter_spec['invalid'] = 'ignored'
    filter.call(event)

    expect(event).to include 'invalid' => 'invalid'
    expect(event).not_to include 'ignored'
  end

  it 'ignores unknown values' do
    filter_spec['unknown'] = 'ignored'
    filter.call(event)

    expect(event).not_to include 'ignored'
  end


  it 'anonymizes arrays' do
    filter_spec['array'] = 'anonymized'
    filter.call(event)

    expect(event).to include 'anonymized' => ['10.123.42.0', '2400:cb00:2048::']
  end

  it 'fails with invalid arguments' do
    expect { described_class.new({}, ipv4_mask: 0) }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv4_mask: -3) }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv4_mask: 33) }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv4_mask: '/24') }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv4_mask: false) }.to raise_error(TypeError)
    expect { described_class.new({}, ipv4_mask: nil) }.to raise_error(TypeError)

    expect { described_class.new({}, ipv6_mask: 0) }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv6_mask: -3) }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv6_mask: 129) }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv6_mask: '/80') }.to raise_error(ArgumentError)
    expect { described_class.new({}, ipv6_mask: false) }.to raise_error(TypeError)
    expect { described_class.new({}, ipv6_mask: nil) }.to raise_error(TypeError)
  end
end
