# frozen_string_literal: true

# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'tempfile'
require 'tmpdir'

require 'rackstash/adapters/file'

describe Rackstash::Adapters::File do
  let!(:logfile) { Tempfile.new('') }

  let(:adapter_args) { {} }
  let(:adapter) { described_class.new(logfile.path, **adapter_args) }

  after(:each) do
    logfile.close
    logfile.unlink
  end

  describe '#initialize' do
    it 'accepts a String' do
      expect(described_class.new(logfile.path).filename)
        .to eql(logfile.path)
        .and be_a String
    end

    it 'accepts a Pathname' do
      expect(described_class.new(Pathname.new(logfile.path)).filename)
        .to eql(logfile.path)
        .and be_a String
    end

    it 'rejects non-IO objects' do
      expect { described_class.new(nil) }.to raise_error TypeError
      expect { described_class.new(Object.new) }.to raise_error TypeError
      expect { described_class.new(23) }.to raise_error TypeError
    end

    it 'creates the file and leading directories' do
      Dir.mktmpdir do |base|
        expect(File.exist?(File.join(base, 'dir'))).to be false

        adapter = described_class.new File.join(base, 'dir', 'sub', 'test.log')

        expect(adapter.filename).to eql File.join(base, 'dir', 'sub', 'test.log')
        expect(File.directory?(File.join(base, 'dir'))).to be true
        expect(File.file?(File.join(base, 'dir', 'sub', 'test.log'))).to be true
      end
    end
  end

  describe '.default_encoder' do
    it 'returns a JSON encoder' do
      expect(adapter.default_encoder).to be_instance_of Rackstash::Encoders::JSON
    end
  end

  describe '#close' do
    it 'closes the IO object' do
      adapter.close
      expect { adapter.write('hello') }.to raise_error IOError
    end
  end

  describe '#reopen' do
    it 're-opens a closed file' do
      adapter.close
      adapter.reopen

      expect { adapter.write('hello') }.not_to raise_error
    end
  end

  describe '#write_single' do
    it 'writes the log line to the file' do
      adapter.write('a log line')
      expect(logfile.tap(&:rewind).read).to eql "a log line\n"
    end

    it 'always writes a string' do
      adapter.write([123, 'hello'])
      expect(logfile.tap(&:rewind).read).to eql "[123, \"hello\"]\n"
    end

    it 'appends a trailing newline if necessary' do
      adapter.write("a full line.\n")
      expect(logfile.tap(&:rewind).read).to eql "a full line.\n"
    end

    context 'with auto_reopen: true' do
      let(:adapter_args) { { auto_reopen: true } }

      it 'reopens the file if moved' do
        expect(adapter.auto_reopen?).to be true

        adapter.write('line1')
        File.rename(logfile.path, "#{logfile.path}.orig")

        adapter.write('line2')

        expect(File.read("#{logfile.path}.orig")).to eql "line1\n"
        expect(File.read(logfile.path)).to eql "line2\n"
      end
    end

    context 'with auto_reopen: false' do
      let(:adapter_args) { { auto_reopen: false } }

      it 'does not reopen the logfile automatically' do
        expect(adapter.auto_reopen?).to be false

        adapter.write('line1')
        File.rename(logfile.path, "#{logfile.path}.orig")

        adapter.write('line2')

        expect(File.read("#{logfile.path}.orig")).to eql "line1\nline2\n"
        expect(File.exist?(logfile.path)).to be false
      end
    end
  end

  context 'with concurrent processes' do
    let(:workers) { 20 }
    let(:lines_per_worker) { 50 }
    let(:line_length) { 4096 }

    def run_worker(worker_id)
      filler = (worker_id + 65).chr
      line = filler * line_length

      adapter = described_class.new(logfile.path)

      # Wait until the parent releases the exclusive lock
      logfile.flock(File::LOCK_SH)

      lines_per_worker.times do
        adapter.write(line)

        # Sleep a bit to ensure more reliable concurrency
        # Yes, testing oncurrent things is messy...
        sleep Random.rand(0.01)
      end
    end

    # This test was adapted from
    # http://www.notthewizard.com/2014/06/17/are-files-appends-really-atomic/
    it 'writes atomic log lines' do
      # First, create an exclusive lock on the logfile to ensure all workers
      # start at about the same time
      logfile.flock(File::LOCK_EX)

      if Concurrent.on_cruby?
        worker_processes = Array.new(workers) { |worker_id|
          Process.fork do
            run_worker worker_id
          end
        }

        # Workers will only start writing once we have released the lock
        logfile.flock(File::LOCK_UN)

        worker_processes.each do |pid|
          Process.wait(pid)
        end
      else
        worker_threads = Array.new(workers) { |worker_id|
          Thread.new do
            run_worker worker_id
          end
        }

        # Worker threads will only start writing once we have released the lock
        logfile.flock(File::LOCK_UN)

        worker_threads.each do |thread|
          thread.join
        end
      end

      # Resulting file size is exactly as expected, i.e. no dropped logs
      # Each line as a trailing newline character.
      expect(logfile.size).to eql workers * lines_per_worker * (line_length + 1)

      # All lines are written without any overlap
      expect(File.new(logfile.path).each_line).to all match(/\A(.)\1{#{line_length - 1}}\n\z/)

      # Ensure that not all lines are written sequentially by the same worker,
      # i.e. there were concurrent writes by multiple workers.
      expect(
        File.new(logfile.path).each_line.each_cons(2).count { |l1, l2| l1.to_s[0] != l2.to_s[0] }
      ).to be > workers
    end
  end
end
