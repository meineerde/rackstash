# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'spec_helper'
require 'tempfile'
require 'tmpdir'

require 'rackstash/adapter/file'

RSpec.describe Rackstash::Adapter::File do
  let!(:logfile) { Tempfile.new('') }

  let(:adapter_args) { {} }
  let(:adapter) { described_class.new(logfile.path, **adapter_args) }

  after(:each) do
    # Cleanup
    FileUtils.rm_f Dir.glob("#{logfile.path}.*")
    logfile.close
    logfile.unlink
  end

  describe 'from_uri' do
    it 'creates a File adapter instance' do
      expect(described_class.from_uri("file:#{logfile.path}"))
        .to be_instance_of described_class
      expect(described_class.from_uri("file://#{logfile.path}"))
        .to be_instance_of described_class
    end

    it 'sets the base_path from the URI path' do
      expect(described_class.from_uri("file:#{logfile.path}").base_path)
        .to eql logfile.path
      expect(described_class.from_uri("file://#{logfile.path}").base_path)
        .to eql logfile.path
    end

    it 'sets optional attributes' do
      adapter = described_class.from_uri('file:/tmp/file_spec.log?rotate=monthly&auto_reopen=false')

      expect(adapter.rotate).to eql '%Y-%m'
      expect(adapter.auto_reopen?).to eql false
    end

    it 'only accepts file URIs' do
      expect { described_class.from_uri('http://example.com') }
        .to raise_error ArgumentError, 'Invalid URI: http://example.com'

      expect { described_class.from_uri('') }
        .to raise_error ArgumentError, 'Invalid URI: '
    end
  end

  describe '#initialize' do
    it 'accepts a String' do
      expect(described_class.new(logfile.path).base_path)
        .to eql(logfile.path)
        .and be_a String
    end

    it 'accepts a Pathname' do
      expect(described_class.new(Pathname.new(logfile.path)).base_path)
        .to eql(logfile.path)
        .and be_a String
    end

    it 'rejects other objects' do
      expect { described_class.new(nil) }.to raise_error TypeError
      expect { described_class.new(Object.new) }.to raise_error TypeError
      expect { described_class.new(23) }.to raise_error TypeError
    end

    it 'creates the file and leading directories' do
      Dir.mktmpdir do |base|
        expect(File.exist?(File.join(base, 'dir'))).to be false

        adapter = described_class.new File.join(base, 'dir', 'sub', 'test.log')

        expect(adapter.base_path).to eql File.join(base, 'dir', 'sub', 'test.log')
        expect(File.directory?(File.join(base, 'dir'))).to be true
        expect(File.file?(File.join(base, 'dir', 'sub', 'test.log'))).to be true

        # cleanup
        adapter.close
        FileUtils.rm_rf Dir[File.join(base, '*')]
      end
    end

    it 'rejects invalid rotate specifications' do
      expect { described_class.new(logfile.path, rotate: :invalid) }.to raise_error ArgumentError
      expect { described_class.new(logfile.path, rotate: 42) }.to raise_error ArgumentError
      expect { described_class.new(logfile.path, rotate: false) }.to raise_error ArgumentError
      expect { described_class.new(logfile.path, rotate: true) }.to raise_error ArgumentError
    end
  end

  describe '.default_encoder' do
    it 'returns a JSON encoder' do
      expect(adapter.default_encoder).to be_instance_of Rackstash::Encoder::JSON
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

    it 'ignores empty log lines' do
      adapter.write('')
      adapter.write(nil)

      expect(logfile.tap(&:rewind).read).to eql ''
    end

    context 'with auto_reopen: true' do
      let(:adapter_args) { { auto_reopen: true } }

      before(:each) do
        logfile.close
        GC.start
      end

      it 'reopens the file if moved' do
        expect(adapter.auto_reopen?).to eql true

        adapter.write('line1')
        File.rename(logfile.path, "#{logfile.path}.moved")

        adapter.write('line2')

        expect(File.read("#{logfile.path}.moved")).to eql "line1\n"
        expect(File.read(logfile.path)).to eql "line2\n"
      end
    end

    context 'with auto_reopen: false' do
      let(:adapter_args) { { auto_reopen: false } }

      before(:each) do
        logfile.close
        GC.start
      end

      it 'does not reopen the logfile automatically' do
        expect(adapter.auto_reopen?).to eql false

        adapter.write('line1')
        File.rename(logfile.path, "#{logfile.path}.moved")

        adapter.write('line2')

        expect(File.read("#{logfile.path}.moved")).to eql "line1\nline2\n"
        expect(File.exist?(logfile.path)).to be false
      end
    end

    context 'with rotate: :daily' do
      before do
        adapter_args[:rotate] = :daily
      end

      it 'rotates daily' do
        date1 = Date.new(2017, 11, 13)
        allow(Date).to receive(:today).and_return(date1)

        adapter.write('line1')
        expect(adapter.path).to eql "#{logfile.path}.2017-11-13"

        date2 = Date.new(2018, 1, 13)
        allow(Date).to receive(:today).and_return(date2)

        adapter.write('line2')
        expect(adapter.path).to eql "#{logfile.path}.2018-01-13"

        expect(File.read "#{logfile.path}.2017-11-13").to eql "line1\n"
        expect(File.read "#{logfile.path}.2018-01-13").to eql "line2\n"
      end
    end

    context 'with rotate: :weekly' do
      before do
        adapter_args[:rotate] = :weekly
      end

      it 'rotates weekly' do
        date1 = Date.new(2018, 12, 24)
        allow(Date).to receive(:today).and_return(date1)

        adapter.write('line1')
        expect(adapter.path).to eql "#{logfile.path}.2018-w52"

        date2 = Date.new(2018, 12, 31)
        allow(Date).to receive(:today).and_return(date2)

        adapter.write('line2')
        expect(adapter.path).to eql "#{logfile.path}.2019-w01"

        expect(File.read "#{logfile.path}.2018-w52").to eql "line1\n"
        expect(File.read "#{logfile.path}.2019-w01").to eql "line2\n"
      end
    end

    context 'with rotate: :monthly' do
      before do
        adapter_args[:rotate] = :monthly
      end

      it 'rotates monthly' do
        date1 = Date.new(2017, 11, 13)
        allow(Date).to receive(:today).and_return(date1)

        adapter.write('line1')
        expect(adapter.path).to eql "#{logfile.path}.2017-11"

        date2 = Date.new(2018, 1, 13)
        allow(Date).to receive(:today).and_return(date2)

        adapter.write('line2')
        expect(adapter.path).to eql "#{logfile.path}.2018-01"

        expect(File.read "#{logfile.path}.2017-11").to eql "line1\n"
        expect(File.read "#{logfile.path}.2018-01").to eql "line2\n"
      end
    end

    context 'with rotate: PATTERN' do
      it 'rotates with current year' do
        adapter_args[:rotate] = 'year-%Y'

        adapter.write('line1')
        expect(adapter.path).to eql "#{logfile.path}.year-#{Date.today.year}"
        expect(File.read "#{logfile.path}.year-#{Date.today.year}").to eql "line1\n"
      end

      it 'rotates with a fixed string' do
        adapter_args[:rotate] = 'ext'

        adapter.write('line1')
        expect(adapter.path).to eql "#{logfile.path}.ext"

        adapter.write('line2')
        expect(adapter.path).to eql "#{logfile.path}.ext"

        expect(File.read "#{logfile.path}.ext").to eql "line1\nline2\n"
      end
    end

    context 'with rotate: block' do
      let(:counter) {
        Struct.new(:count) do
          def inc
            self.count += 1
          end
        end.new(0)
      }

      it 'rotates' do
        adapter_args[:rotate] = -> { "count_#{counter.inc}" }
        expect(adapter.path).to eql "#{logfile.path}.count_1"

        adapter.write('line1')
        expect(adapter.path).to eql "#{logfile.path}.count_2"

        adapter.write('line2')
        expect(adapter.path).to eql "#{logfile.path}.count_3"

        expect(File.read "#{logfile.path}.count_1").to be_empty
        expect(File.read "#{logfile.path}.count_2").to eql "line1\n"
        expect(File.read "#{logfile.path}.count_3").to eql "line2\n"
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
