require "timeout"

module Ops
  module ManagedCommand
    def self.run(command)
      pid = Process.spawn(*command, pgroup: true)
      status = nil
      begin
        _, status = Process.wait2(pid)
        status
      ensure
        unless status
          begin
            Process.kill("TERM", -pid)
            Timeout.timeout(3) { Process.waitpid(pid) }
          rescue Timeout::Error
            Process.kill("KILL", -pid) rescue nil
            Process.waitpid(pid) rescue nil
          rescue Errno::ESRCH, Errno::ECHILD
            # The owned process group has already stopped.
          end
        end
      end
    end
  end
end
