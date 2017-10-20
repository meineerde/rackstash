# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'fileutils'
require 'pathname'
require 'thread'

require 'rackstash/adapter/adapter'

module Rackstash
  module Adapter
    # This log adapter allows to write logs to a file acessible on the local
    # filesystem. We assume filesystem semantics of the usual local filesystems
    # used on Linux, macOS, BSDs, or Windows. Here, we can ensure that even
    # concurrent writes of multiple processes (e.g. multiple worker processes of
    # an application server) don't produce interleaved log lines.
    #
    # When using a remote filesystem (e.g. NFS or most FUSE filesystems but not
    # for SMB) it might be possible that concurrent log writes to the same file
    # are interleaved on disk, resulting on probable log corruption. If this is
    # a concern, you should make sure that only one log adapter of one process
    # write to a log file at a time or (preferrably) write to a local file
    # instead.
    #
    # When reading the log file, the reader might still see incomplete writes
    # depending on the OS and filesystem. Since we are only writing complete
    # lines, it should be safe to continue reading until you observe a newline
    # (`\n`) character.
    #
    # Assuming you are creating the log adapter like this
    #
    #     Rackstash::Adapter::File.new('/var/log/rackstash/my_app.log')
    #
    # you can rotate the file with a config for the standard
    # [logrotate](https://github.com/logrotate/logrotate) utility similar to
    # this example:
    #
    #     /var/log/rackstash/my_app.log {
    #       daily
    #       rotate 30
    #
    #       # file might be missing if there were no writes that day
    #       missingok
    #       notifempty
    #
    #       # compress old logfiles but keep the newest rotate file uncompressed
    #       # to still allow writes during rotation
    #       compress
    #       delaycompress
    #     }
    #
    # Since the {File} adapter automatically reopens the logfile after the
    # file was moved, you don't need to create the new file there nor should you
    # use the (potentially destructive) `copytruncate` option of logrotate.
    class File < Adapter
      register_for ::String, ::Pathname

      # @return [String] the absolute path to the log file
      attr_reader :filename

      # Create a new file adapter instance which writes logs to the log file
      # specified in `filename`.
      #
      # We will always resolve `filename` to an absolute path once during
      # initialization. When passing a relative path, it will be resolved
      # according to the current working directory. See
      # [`::File.expand_path`](https://ruby-doc.org/core/File.html#method-c-expand_path)
      # for details.
      #
      # @param filename [String, Pathname] the path to the logfile
      # @param auto_reopen [Boolean] set to `true` to automatically reopen the
      #   log file (and potentially create a new one) if we detect that the
      #   current log file was moved or deleted, e.g. due to an external
      #   logrotate run
      def initialize(filename, auto_reopen: true)
        @filename = ::File.expand_path(filename).freeze
        @auto_reopen = !!auto_reopen

        @mutex = Mutex.new
        open_file
      end

      # @return [Boolean] if `true`, the logfile will be automatically reopened
      #   on write if it is (re-)moved on the filesystem
      def auto_reopen?
        @auto_reopen
      end

      # Write a single log line with a trailing newline character to the open
      # file. If {#auto_reopen?} is `true`, we will reopen the file object
      # before the write if we detect that the file was moved, e.g., from an
      # external logrotate run.
      #
      # When writing the log line, ruby uses a single `fwrite(2)` syscall with
      # `IO#write`. Since we are using unbuffered (sync) IO, concurrent writes
      # to the file from multiple processes
      # [are guaranteed](https://stackoverflow.com/a/35256561/421705) to be
      # serialized by the kernel without overlap.
      #
      # @param log [#to_s] the encoded log event
      # @return [nil]
      def write_single(log)
        line = normalize_line(log)
        return if line.empty?

        @mutex.synchronize do
          auto_reopen
          @file.write(line)
        end
        nil
      end

      # Close the file. After closing, no further writes are possible. Further
      # attempts to {#write} will result in an exception being thrown.
      #
      # We will not automatically reopen a closed file on {#write}. You have to
      # explicitly call {#reopen} in this case.
      #
      # @return [nil]
      def close
        @mutex.synchronize do
          @file.close
        end
        nil
      end

      # Reopen the logfile. We will open the file located at the original
      # {#filename} or create a new one if it does not exist.
      #
      # If the file can not be opened, an exception will be raised.
      # @return [nil]
      def reopen
        @mutex.synchronize do
          reopen_file
        end
        nil
      end

      private

      # Reopen the log file if the original filename does not reference the
      # opened file anymore (e.g. because it was moved or deleted)
      def auto_reopen
        return unless @auto_reopen

        return if @file.closed?
        return if ::File.identical?(@file, @filename)

        reopen_file
      end

      def open_file
        unless ::File.exist? ::File.dirname(@filename)
          FileUtils.mkdir_p ::File.dirname(@filename)
        end

        file = ::File.new(
          filename,
          ::File::WRONLY | ::File::APPEND | ::File::CREAT,
          external_encoding: Encoding::UTF_8
        )
        file.binmode
        file.sync = true

        @file = file
        nil
      end

      def reopen_file
        @file.close rescue nil
        open_file
      end
    end
  end
end
