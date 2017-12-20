# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/filter_chain'

describe Rackstash::FilterChain do
  let(:filter_chain) { described_class.new }

  Struct.new('MyFilter') do
    def call(event)
      event
    end
  end

  def a_filter
    Struct::MyFilter.new
  end

  let(:filter) { a_filter }

  describe '#initialize' do
    it 'accepts a single filter' do
      filter_chain = described_class.new(-> {})
      expect(filter_chain.length).to eql 1
    end

    it 'accepts a list of filters' do
      chain = described_class.new([-> {}, -> {}, -> {}])
      expect(chain.length).to eql 3
    end
  end

  describe '#[]' do
    it 'returns the filter by index' do
      filter_chain << filter

      expect(filter_chain[0]).to equal filter
      expect(filter_chain[-1]).to equal filter

      expect(filter_chain[1]).to be_nil
      expect(filter_chain[-2]).to be_nil
    end

    it 'returns the filter by class or ancestor' do
      filter_chain << filter

      expect(filter_chain[Struct::MyFilter]).to equal filter
      expect(filter_chain[Struct]).to equal filter
      expect(filter_chain[Integer]).to be_nil
    end

    it 'returns the filter by class or ancestor name' do
      filter_chain << filter

      expect(filter_chain['Struct::MyFilter']).to equal filter
      expect(filter_chain['Struct']).to equal filter
      expect(filter_chain['Integer']).to be_nil
    end

    it 'returns the filter by equivalence' do
      filter_chain << filter

      expect(filter_chain[filter]).to equal filter
      expect(filter_chain[false]).to be_nil
      expect(filter_chain[true]).to be_nil
    end
  end

  describe '#[]=' do
    before(:each) do
      filter_chain << filter
      filter_chain << -> {}
    end

    let(:new_filter) { -> {} }

    it 'sets a filter by index' do
      filter_chain[0] = new_filter
      expect(filter_chain[0]).to equal new_filter

      filter_chain[2] = new_filter
      expect(filter_chain[2]).to equal new_filter
    end

    it 'sets a filter by class or ancestor' do
      filter_chain[Proc] = new_filter
      expect(filter_chain[1]).to equal new_filter

      filter_chain[Struct] = new_filter
      expect(filter_chain[0]).to equal new_filter
    end

    it 'sets a filter by class or ancestor name' do
      filter_chain['Proc'] = new_filter
      expect(filter_chain[1]).to equal new_filter

      filter_chain['Struct'] = new_filter
      expect(filter_chain[0]).to equal new_filter
    end

    it 'sets a filter by equivalence' do
      filter_chain[filter] = new_filter
      expect(filter_chain[0]).to equal new_filter
    end

    it 'raises an ArgumentError if the filter was not found' do
      expect { filter_chain[false] = new_filter }.to raise_error ArgumentError
      expect { filter_chain[nil] = new_filter }.to raise_error ArgumentError
      expect { filter_chain['foo'] = new_filter }.to raise_error ArgumentError
      expect { filter_chain[Class.new] = new_filter }.to raise_error ArgumentError
      expect { filter_chain[34] = new_filter }.to raise_error ArgumentError
    end

    it 'raises an error if the object is not a filter' do
      expect { filter_chain[0] = :foo }.to raise_error TypeError
      expect { filter_chain[0] = nil }.to raise_error TypeError
      expect { filter_chain[0] = false }.to raise_error TypeError
      expect { filter_chain[0] = 42 }.to raise_error TypeError
      expect { filter_chain[0] = 'Foo' }.to raise_error TypeError
    end
  end

  describe '#append' do
    it 'appends a filter' do
      expect(filter_chain.append(filter)).to equal filter_chain
      expect(filter_chain[0]).to eql filter
    end

    it 'appends a block as the filter' do
      expect(filter_chain.append { :foo }).to equal filter_chain
      expect(filter_chain[0]).to be_instance_of(Proc)
    end

    it 'raises an error if the object is not a filter' do
      expect { filter_chain.append(nil) }.to raise_error TypeError
      expect { filter_chain.append(false) }.to raise_error TypeError
      expect { filter_chain.append(42) }.to raise_error TypeError

      # Registered filter was not found
      expect { filter_chain.append(:foo) }.to raise_error KeyError
      expect { filter_chain.append('Foo') }.to raise_error KeyError

      expect { filter_chain.append }.to raise_error ArgumentError
    end

    it 'can use #<< alias' do
      expect(filter_chain << filter).to equal filter_chain
      expect(filter_chain[0]).to eql filter
    end

    it 'can use #push alias' do
      expect(filter_chain.push(filter)).to equal filter_chain
      expect(filter_chain[0]).to eql filter
    end
  end

  describe '#call' do
    it 'calls all the filters' do
      event = {}
      filters = [a_filter, a_filter, a_filter]
      filters.each do |filter|
        filter_chain << filter
      end

      expect(filters).to all receive(:call).with(event)
      filter_chain.call({})
    end

    it 'returns the event' do
      event = {}

      expect(filter_chain.call(event)).to equal event

      filter_chain << filter
      expect(filter_chain.call(event)).to equal event
    end

    it 'stops once a filter returns false' do
      filters = [a_filter, a_filter, a_filter]
      filters.each do |filter|
        filter_chain << filter
      end

      expect(filters[0]).to receive(:call)
      expect(filters[1]).to receive(:call).and_return(false)
      expect(filters[2]).not_to receive(:call)

      expect(filter_chain.call({})).to be false
    end
  end

  describe '#delete' do
    before(:each) do
      filter_chain << -> {}
      filter_chain << filter
    end

    it 'deletes by index' do
      expect(filter_chain.delete(1)).to equal filter
      expect(filter_chain.count).to eql 1
    end

    it 'deletes by class' do
      expect(filter_chain.delete(Struct)).to equal filter
      expect(filter_chain.count).to eql 1
    end

    it 'deletes by class name' do
      expect(filter_chain.delete('Struct')).to equal filter
      expect(filter_chain.count).to eql 1
    end

    it 'deletes by reference' do
      expect(filter_chain.delete(filter)).to equal filter
      expect(filter_chain.count).to eql 1
    end

    it 'returns nil if the filter was not found' do
      expect(filter_chain.delete(nil)).to be_nil
      expect(filter_chain.delete(true)).to be_nil
      expect(filter_chain.delete(false)).to be_nil
      expect(filter_chain.delete('Blar')).to be_nil
      expect(filter_chain.delete(Object.new)).to be_nil
      expect(filter_chain.delete(Class.new)).to be_nil

      # at the end, all filters are still present
      expect(filter_chain.count).to eql 2
    end
  end

  describe '#dup' do
    it 'duplicates the filters array' do
      filter_chain << a_filter
      dupped = filter_chain.dup

      expect(filter_chain.length).to eql dupped.length
      expect { filter_chain << a_filter }.not_to change { dupped.length }
    end
  end

  describe '#each' do
    it 'yields each filter' do
      filter_chain << -> {}
      filter_chain << filter

      expect { |b| filter_chain.each(&b) }
        .to yield_successive_args(instance_of(Proc), filter)
    end

    it 'returns the filter chain if a block was provided' do
      filter_chain << -> {}
      expect(filter_chain.each {}).to equal filter_chain
    end

    it 'returns an Enumerator if no block was provided' do
      filter_chain << -> {}
      expect(filter_chain.each).to be_instance_of Enumerator
    end

    it 'operators on a copy of the internal data' do
      yielded = 0
      filter_chain << -> {}

      filter_chain.each do |flow|
        yielded += 1
        filter_chain[1] = flow
      end

      expect(yielded).to eql 1
    end
  end

  describe '#index' do
    it 'finds the filter index' do
      filter_chain << filter

      expect(filter_chain.index(0)).to eql 0
      expect(filter_chain.index(Struct)).to eql 0
      expect(filter_chain.index('Struct')).to eql 0
      expect(filter_chain.index(filter)).to eql 0
    end

    it 'returns nil if the filter was not found' do
      expect(filter_chain.index(nil)).to be_nil
      expect(filter_chain.index(true)).to be_nil
      expect(filter_chain.index(false)).to be_nil
      expect(filter_chain.index('Blar')).to be_nil
      expect(filter_chain.index(Object.new)).to be_nil
      expect(filter_chain.index(Class.new)).to be_nil
    end
  end

  describe '#insert_before' do
    before(:each) do
      filter_chain << -> {}
      filter_chain << filter
    end

    let(:inserted) { -> {} }

    it 'inserts before index' do
      expect(filter_chain.insert_before(1, inserted)).to equal filter_chain
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to equal filter
    end

    it 'inserts before class' do
      expect(filter_chain.insert_before(Struct, inserted)).to equal filter_chain
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to equal filter
    end

    it 'inserts before class name' do
      expect(filter_chain.insert_before('Struct', inserted)).to equal filter_chain
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to equal filter
    end

    it 'inserts before reference' do
      expect(filter_chain.insert_before(filter, inserted)).to equal filter_chain
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to equal filter
    end

    it 'raises ArgumentError if the filter was not found' do
      expect { filter_chain.insert_before(nil, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_before(true, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_before(false, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_before('Blar', inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_before(Object.new, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_before(Class.new, inserted) }.to raise_error ArgumentError
    end

    it 'raises a TypeError if the object is not a filter' do
      expect { filter_chain.insert_before(1, nil) }.to raise_error TypeError
      expect { filter_chain.insert_before(1, false) }.to raise_error TypeError
      expect { filter_chain.insert_before(1, 42) }.to raise_error TypeError

      # Registered filter was not found
      expect { filter_chain.insert_before(1, :foo) }.to raise_error KeyError
      expect { filter_chain.insert_before(1, 'Foo') }.to raise_error KeyError

      expect { filter_chain.insert_before(1) }.to raise_error ArgumentError
    end
  end

  describe '#insert_after' do
    before(:each) do
      filter_chain << filter
      filter_chain << -> {}
    end

    let(:inserted) { -> {} }

    it 'inserts after index' do
      expect(filter_chain.insert_after(0, inserted)).to equal filter_chain
      expect(filter_chain[0]).to equal filter
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to be_instance_of(Proc)
    end

    it 'inserts after class' do
      expect(filter_chain.insert_after(Struct, inserted)).to equal filter_chain
      expect(filter_chain[0]).to equal filter
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to be_instance_of(Proc)
    end

    it 'inserts after class name' do
      expect(filter_chain.insert_after('Struct', inserted)).to equal filter_chain
      expect(filter_chain[0]).to equal filter
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to be_instance_of(Proc)
    end

    it 'inserts after reference' do
      expect(filter_chain.insert_after(filter, inserted)).to equal filter_chain
      expect(filter_chain[0]).to equal filter
      expect(filter_chain[1]).to equal inserted
      expect(filter_chain[2]).to be_instance_of(Proc)
    end

    it 'raises ArgumentError if the filter was not found' do
      expect { filter_chain.insert_after(nil, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_after(true, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_after(false, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_after('Blar', inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_after(Object.new, inserted) }.to raise_error ArgumentError
      expect { filter_chain.insert_after(Class.new, inserted) }.to raise_error ArgumentError
    end

    it 'raises an error if the object is not a filter' do
      expect { filter_chain.insert_after(1, nil) }.to raise_error TypeError
      expect { filter_chain.insert_after(1, false) }.to raise_error TypeError
      expect { filter_chain.insert_after(1, 42) }.to raise_error TypeError

      # Registered filter was not found
      expect { filter_chain.insert_after(1, :foo) }.to raise_error KeyError
      expect { filter_chain.insert_after(1, 'Foo') }.to raise_error KeyError

      expect { filter_chain.insert_after(1) }.to raise_error ArgumentError
    end
  end

  describe '#inspect' do
    it 'formats the object' do
      filter_chain << filter

      expect(filter).to receive(:inspect).and_return('"<filter>"')
      expect(filter_chain.inspect).to(
        match %r{\A#<Rackstash::FilterChain:0x[a-f0-9]+ \["<filter>"\]>\z}
      )
    end
  end

  describe '#length' do
    it 'returns the number of flows' do
      expect { filter_chain << -> {} }
        .to change { filter_chain.length }.from(0).to(1)
    end

    it 'can use size alias' do
      expect { filter_chain << -> {} }
        .to change { filter_chain.size }.from(0).to(1)
    end

    it 'can use count alias' do
      expect { filter_chain << -> {} }
        .to change { filter_chain.count }.from(0).to(1)
    end
  end

  describe '#unshift' do
    before(:each) do
      filter_chain << -> {}
    end

    it 'prepends a filter' do
      filter_chain.unshift filter
      expect(filter_chain[0]).to eql filter
      expect(filter_chain.size).to eql 2
    end

    it 'prepends a block as the filter' do
      filter_chain.unshift { :foo }
      expect(filter_chain[0]).to be_instance_of(Proc)
      expect(filter_chain.size).to eql 2
    end

    it 'raises an error if the object is not a filter' do
      expect { filter_chain.unshift(nil) }.to raise_error TypeError
      expect { filter_chain.unshift(false) }.to raise_error TypeError
      expect { filter_chain.unshift(42) }.to raise_error TypeError

      # Registered filter was not found
      expect { filter_chain.unshift(:foo) }.to raise_error KeyError
      expect { filter_chain.unshift('Foo') }.to raise_error KeyError

      expect { filter_chain.unshift }.to raise_error ArgumentError
    end

    it 'can use #prepend alias' do
      filter_chain.prepend filter
      expect(filter_chain[0]).to eql filter
    end
  end

  describe '#to_a' do
    it 'returns the array representation' do
      filter_chain << filter

      expect(filter_chain.to_a)
        .to be_instance_of(Array)
        .and all be_equal(filter)
    end

    it 'returns a duplicate' do
      filter_chain << a_filter
      array = filter_chain.to_a

      expect { array << a_filter }.not_to change { filter_chain.length }
    end
  end

  describe '#to_s' do
    it 'returns the array representation' do
      filter_chain << -> {}

      expect(filter_chain.to_s).to eql filter_chain.to_a.to_s
    end
  end
end
