# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'

require 'rackstash/target_list'
require 'rackstash/target'

describe Rackstash::TargetList do
  let(:target_list) { Rackstash::TargetList.new }

  def a_target
    target = instance_double('Rackstash::Target')
    allow(target).to receive(:is_a?).with(Rackstash::Target).and_return(true)
    target
  end

  describe '#initialize' do
    it 'accepts a single target' do
      list = Rackstash::TargetList.new(a_target)
      expect(list.size).to eql 1
    end

    it 'accepts a list of targets' do
      targets = 3.times.map { a_target }

      list_with_array = Rackstash::TargetList.new(targets)
      expect(list_with_array.size).to eql 3

      list_with_splat = Rackstash::TargetList.new(*targets)
      expect(list_with_splat.size).to eql 3
    end
  end

  describe '#<<' do
    let(:target) { a_target }

    it 'adds a new target at the end of the list' do
      expect(target_list.size).to eql 0
      target_list << target
      expect(target_list.size).to eql 1
      expect(target_list[0]).to equal target
    end

    it 'tries to find a matching target' do
      wrapped = Object.new
      target = Object.new

      target_class = class_double('Rackstash::Target').as_stubbed_const
      expect(target_class).to receive(:new).with(wrapped).and_return(target)

      expect(target_list.size).to eql 0
      target_list << wrapped
      expect(target_list.size).to eql 1
      expect(target_list[0]).to equal target
    end

    it 'can use the #add alias' do
      expect(target_list.size).to eql 0
      target_list.add target
      expect(target_list.size).to eql 1
      expect(target_list[0]).to equal target
    end
  end

  describe '#[]' do
    let(:target) { a_target }

    it 'returns the index target' do
      target_list << target
      expect(target_list[0]).to equal target
      expect(target_list[1]).to be_nil
    end
  end

  describe '#[]=' do
    it 'sets a target' do
      original_target = a_target
      new_target = a_target

      target_list << original_target
      expect(target_list[0]).to equal original_target

      target_list[0] = new_target
      expect(target_list[0]).to equal new_target
    end

    it 'adds nil targets if necessary' do
      target = a_target
      target_list[3] = target
      expect(target_list.to_a).to eql [nil, nil, nil, target]
    end

    it 'tries to find a matching target' do
      wrapped = Object.new
      target = Object.new

      target_class = class_double('Rackstash::Target').as_stubbed_const
      expect(target_class).to receive(:new).with(wrapped).and_return(target)

      target_list[0] = wrapped
      expect(target_list[0]).to equal target
    end
  end

  describe '#empty?' do
    it 'is true if empty' do
      expect(target_list).to be_empty
      target_list << a_target
      expect(target_list).not_to be_empty
    end
  end

  describe '#inspect' do
    it 'formats the object' do
      expect(target_list).to receive(:to_s).and_return('["<target>"]')
      expect(target_list.inspect).to(
        match %r{\A#<Rackstash::TargetList:0x[a-f0-9]+ \["<target>"\]>\z}
      )
    end
  end

  describe '#length' do
    it 'returns the number of targets' do
      expect { target_list << a_target}
        .to change { target_list.length }.from(0).to(1)
    end

    it 'can use size alias' do
      expect { target_list << a_target}
        .to change { target_list.size }.from(0).to(1)
    end
  end

  describe '#to_ary' do
    it 'returns an array' do
      target_list << a_target

      expect(target_list.to_a).to be_an_instance_of(::Array)
      expect(target_list.to_a).not_to be_empty
    end

    it 'returns a new object each time' do
      array = target_list.to_a
      expect(target_list.to_a).to eql array
      expect(target_list.to_a).not_to equal array

      array << a_target
      expect(target_list.to_a).not_to eql array
    end
  end

  describe '#to_s' do
    it 'returns the array representation' do
      target_list << a_target

      expect(target_list.to_s).to eql target_list.to_a.to_s
    end
  end
end
