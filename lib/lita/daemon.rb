module Lita
  class Daemon
    
    def self.start(pid, options = { })
      pid_file    = options[:pid_file] || "/tmp/lita.pid"
      stdout_file = options[:stdout_file] || "/tmp/lita.stdout.log"
      stderr_file = options[:stderr_file] || "/tmp/lita.stderr.log"
      
      unless pid.nil?
        raise "Fork failed" if pid == -1
        # Make sure that there are no existing processes using an
        # existing pid file
        write_pid(pid, pid_file) if kill(pid, pid_file)
        exit
      else
        redirect_logs(stdout_file, stderr_file)
      end
    end
    
    # Attempts to write the pid of the forked process to the pid file
    def self.write_pid(pid, pidfile)
      File.open(pidfile, "w") { |f| f.write(pid) }
    rescue ::Exception => e
      $stderr.puts "Unable to write pid file: unexpected #{e.class}: #{e}"
      Process.kill("QUIT", pid)
    end

    # Attempts to kill any existing processes for rolling restarts
    def self.kill(pid, pidfile)
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
    def self.redirect_logs(outfile, errfile)
      $stdin.reopen('/dev/null')
      out = File.new(outfile, "a")
      err = File.new(errfile, "a")
      $stdout.reopen(out)
      $stderr.reopen(err)
      $stdout.sync = true
      $stderr.sync = true
    end
  end
end
