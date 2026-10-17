require "open3"
require "shellwords"
require "timeout"

module Ops
  module DeployLock
    Error = Class.new(StandardError)
    LockTimeout = Class.new(Error)
    ConnectionLost = Class.new(Error)
    ConfigurationError = Class.new(Error)
    LOCK_PATH = "/var/lock/live-deploy/global.lock".freeze

    def self.with_lock(host:, key_path:, timeout: 900)
      wait_seconds = Integer(timeout)
      unless host.to_s.match?(/\A[a-z0-9][a-z0-9.-]*\z/) && File.file?(key_path.to_s) && (0..3600).cover?(wait_seconds)
        raise ConfigurationError, "Ungültige Parameter für die Deploy-Sperre"
      end
      remote = "flock -w #{wait_seconds} -E 73 #{LOCK_PATH} sh -c #{Shellwords.escape("printf 'LOCKED\\n'; cat >/dev/null")}"
      arguments = [ "ssh", "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=10",
        "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=2", "-o", "LogLevel=ERROR", "-i", key_path.to_s, "deploy@#{host}", remote ]
      owner = Thread.current
      Thread.handle_interrupt(ConnectionLost => :never) do
        Open3.popen3(*arguments) do |input, output, error, waiter|
          releasing = false
          monitor = nil
          drain = Thread.new { error.each_line { |_line| } }
          begin
            acknowledgement = begin
              Timeout.timeout(wait_seconds + 15) { output.gets&.chomp }
            rescue Timeout::Error
              raise LockTimeout, "Zeitlimit für die gemeinsame Deploy-Sperre erreicht"
            end
            unless acknowledgement == "LOCKED"
              raise LockTimeout, "Zeitlimit für die gemeinsame Deploy-Sperre erreicht" if waiter.value.exitstatus == 73
              raise ConnectionLost, "SSH-Deploy-Sperre konnte nicht angefordert werden"
            end
            monitor = Thread.new do
              waiter.value
              owner.raise(ConnectionLost, "SSH-Deploy-Sperre während des Vorgangs verloren") unless releasing
            end
            Thread.handle_interrupt(ConnectionLost => :immediate) { yield }
          ensure
            releasing = true
            monitor&.kill
            input.close unless input.closed?
            begin
              Timeout.timeout(5) { waiter.value }
            rescue Timeout::Error
              Process.kill("TERM", waiter.pid) rescue nil
            end
            output.close unless output.closed?
            error.close unless error.closed?
            drain.kill
          end
        end
      end
    end
  end
end
