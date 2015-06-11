require "fileutils"

module Lita
  # Converts Lita to a daemon process.
  class Daemon

    attr_accessor :pid_file, :log_file

    # @param pid_path [String] The path to the PID file.
    # @param log_path [String] The path to the log file.
    # @param kill_existing [Boolean] Whether or not to kill existing processes.
    def initialize(pid_file: nil, log_file: nil)
      self.pid_file = pid_file
      self.log_file = log_file
      # @kill_existing = kill_existing # Ignoring this for now... maybe implement later.
    end

    # Converts Lita to a daemon process.
    # @return [void]
    def daemonize
      # Kill the original parent process if we can fork
      case fork
      when nil
        # Break away from the terminal, become a new process & group leader
        Process.setsid
        start(fork)
      when -1
        raise ForkingException, "Forking failed for some reason.  Does this OS support forking?"
      else
        exit
      end
    end

    private

    # Starts the final form of the daemon, writes out a pid, redirects logs, etc.
    def start(pid)
      self.pid_file ||= "/tmp/lita.pid"
      self.log_file ||= "/tmp/lita.log"

      case pid
      when nil
        # nil for the fork value means we're in the child process
        redirect_streams(self.log_file)
      when -1
        # Couldn't fork for some reason - usually OS related
        raise ForkingException, "Forking failed for some reason.  Does this OS support forking?"
      else
        # Try to kill any existing processes, write pid, exit
        write_pid(pid, self.pid_file) if kill(pid, self.pid_file)
        exit
      end
    end

    # Attempts to write the pid of the forked process to the pid file
    def write_pid(pid, pid_file)
      File.open(pid_file, "w") { |f| f.write(pid) }
    rescue Errno::EPERM, Errno::EACCES
      safe_pid_location = File.join(Dir.home, "lita.pid")
      warn "Unable to write pid to: #{pid_file}.  Writing pid to #{safe_pid_location} instead."
      File.open(safe_pid_location, "w") { |f| f.write(pid) }
    rescue ::Exception => e
      $stderr.puts "Unable to write pid file: unexpected #{e.class}: #{e}"
      Process.kill("QUIT", pid)
    end

    # Attempts to kill any existing processes for rolling restarts
    def kill(pid, pidfile)
      existing_pid = open(pidfile).read.strip.to_i
      Process.kill("QUIT", existing_pid)
      true
    rescue Errno::ESRCH, Errno::ENOENT
      true
    rescue Errno::EPERM
      $stderr.puts "Permission denied trying to kill #{existing_pid}: Errno::EPERM"
      false
    rescue ::Exception => e
      $stderr.puts "Unexpected #{e.class}: #{e}"
      false
    end

    # Redirect the stdout and stderr to log files
    def redirect_streams(log_file)
      redirect_stream($stdin, '/dev/null', 'stdin', mode: 'r', sync: false)
      redirect_stream($stdout, log_file, 'stdout')
      redirect_stream($stderr, log_file, 'stderr')
    end
    
    def redirect_stream(stream, location, stream_name, mode: 'a', sync: true)
      log_file = File.new(location, mode)
    rescue Errno::EPERM, Errno::EACCESS
      default_location = File.join(Dir.home, "lita.#{stream_name}.log")
      warn "Unable to write to: #{location}. Writing to `#{default_location}' instead."
      log_file = File.new(default_location, mode)
    ensure
      stream.reopen(log_file)
      stream.sync = sync
    end

  end
end
