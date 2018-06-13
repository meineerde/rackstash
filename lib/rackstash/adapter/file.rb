# frozen_string_literal: true
#
# Copyright 2017 - 2018 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require 'fileutils'
require 'pathname'
require 'thread'

require 'rackstash/adapter/base_adapter'

module Rackstash
  module Adapter
    # This log adapter allows to write logs to a file accessible on the local
    # filesystem. Written log lines are delimited by a newline character (`\n`).
    # A suitable encoders should ensure that single logs do not contain any
    # verbatim newline characters themselves. All Rackstash encoders producing
    # JSON formatted logs are suitable in this regard.
    #
    # When writing the logs, we assume filesystem semantics of the usual local
    # filesystems used on Linux, macOS, BSDs, or Windows. Here, we can ensure
    # that even concurrent writes of multiple processes (e.g. multiple worker
    # processes of an application server) don't produce interleaved log lines.
    #
    # When using a remote filesystem it might be possible that concurrent log
    # writes to the same file are interleaved on disk, resulting on probable
    # log corruption. If this is a concern, you should make sure that only one
    # log adapter of one process write to a log file at a time or (preferrably)
    # write to a local file instead. This restriction applies to NFS and most
    # FUSE filesystems like sshfs. SMB is likely safe to use here.
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
    class File < BaseAdapter
      register_for ::String, ::Pathname, 'file'

      # @return [String] the absolute path to the currently opened log file
      attr_reader :path

      # @return [String] the absolute path to the originally defined log file.
      #   Depending on the {#rotate} setting, the final log file might have a
      #   date-based suffix added before its file extension. Use {#path} to
      #   get the full path of the currently opened log file.
      attr_reader :base_path

      # @return [String, Proc, nil] date pattern for the file suffix used for
      #   auto-rotated log files. The pattern is used with `Date#strftime` to
      #   determine the file suffix for the current rotate file. When setting a
      #   `Proc`, it is expected to return the currently final log file suffix
      #   (not just a date pattern). When setting the value to `nil`, the log
      #   file is not rotated.
      attr_reader :rotate

      def self.from_uri(uri)
        uri = URI(uri)

        if (uri.scheme || uri.opaque) == 'file'.freeze
          file_options = parse_uri_options(uri)
          if file_options[:auto_reopen] =~ /\A(:?false|0)?\z/i
            file_options[:auto_reopen] = false
          end

          new(uri.path, **file_options)
        else
          raise ArgumentError, "Invalid URI: #{uri}"
        end
      end

      # Create a new file adapter instance which writes logs to the log file
      # specified in `path`.
      #
      # We will always resolve the `path` to an absolute path once during
      # initialization. When passing a relative path, it will be resolved
      # according to the current working directory. See
      # [`::File.expand_path`](https://ruby-doc.org/core/File.html#method-c-expand_path)
      # for details.
      #
      # @param path [String, Pathname] the path to the logfile. Depending on the
      #   `rotate` setting, the final log file might have a date-based suffix
      #   added before its file extension.
      # @param auto_reopen (see #auto_reopen=)
      # @param rotate (see #rotate=)
      def initialize(path, auto_reopen: true, rotate: nil)
        @base_path = ::File.expand_path(path).freeze

        self.auto_reopen = auto_reopen
        self.rotate = rotate

        @mutex = Mutex.new
        open_file(rotated_path)
      end

      # @return [Boolean] if `true`, the logfile will be automatically reopened
      #   on write if it is (re-)moved on the filesystem
      def auto_reopen?
        @auto_reopen
      end

      # @param auto_reopen [Boolean] set to `true` to automatically reopen the
      #   log file (and potentially create a new one) if we detect that the
      #   current log file was moved or deleted, e.g. due to an external
      #   logrotate run
      def auto_reopen=(auto_reopen)
        @auto_reopen = !!auto_reopen
      end

      # @param rotate [String, Proc, nil] date pattern for the file suffix used
      #   for auto-rotated log files. When giving a `String` here, it is
      #   interpreted as a pattern for the `Date#strftime` method. In addition
      #   to that, we accept the following names: `"daily"`, `"weekly"`, and
      #   `"monthly"` for pre-defined suffixes. When giving a `Proc`, it is
      #   expected to return the final suffix on call (i.e. not just a
      #   `Date#strftime` pattern but the actual file suffix). When defining a
      #   rotate pattern, each log event is written to a file with the resulting
      #   suffix added before its file extension.
      def rotate=(rotate)
        @rotate = case rotate
        when :daily, 'daily'.freeze
          '%Y-%m-%d'.freeze
        when :weekly, 'weekly'.freeze
          '%G-w%V'.freeze
        when :monthly, 'monthly'.freeze
          '%Y-%m'.freeze
        when String
          rotate.dup.freeze
        when Proc, nil
          rotate
        else
          raise ArgumentError, "Invalid rotate specification: #{rotate.inspect}"
        end
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
          rotate_file
          @file.syswrite(line)
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
      # {#path} or create a new one if it does not exist.
      #
      # If the file can not be opened, an exception will be raised.
      # @return [nil]
      def reopen
        @mutex.synchronize do
          reopen_file rotated_path
        end
        nil
      end

      private

      # Reopen the log file if the original {#path} does not reference the
      # opened file anymore (e.g. because it was moved or deleted)
      def auto_reopen!
        return unless @auto_reopen
        return unless @file && @path

        return if @file.closed?
        return if ::File.identical?(@file, @path)

        reopen_file(@path)
      end

      def open_file(path)
        dirname = ::File.dirname(path)
        FileUtils.mkdir_p(dirname) unless ::File.exist?(dirname)

        file = ::File.new(
          path,
          ::File::WRONLY | ::File::APPEND | ::File::CREAT
        )
        file.binmode
        file.sync = true

        @path = path
        @file = file
        nil
      end

      def reopen_file(path)
        @file.close rescue nil
        open_file(path)
      end

      def rotate_file
        path = rotated_path

        if path == @path
          auto_reopen!
        else
          reopen_file(path)
        end
      end

      def rotated_path
        suffix = case @rotate
        when String
          Date.today.strftime(@rotate)
        when Proc
          @rotate.call.to_s
        else
          EMPTY_STRING
        end

        return @base_path if suffix.empty?

        suffix = ".#{suffix}"
        @base_path.sub(/\A(.*?)(\.[^.\/]+)?\z/) { "#{$1}#{suffix}#{$2}" }
      end
    end
  end
end
