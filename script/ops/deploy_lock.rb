require "open3"
require "shellwords"
require "timeout"
require "securerandom"
require_relative "host_operation_fence"

module Ops
  module DeployLock
    Error = Class.new(StandardError)
    LockTimeout = Class.new(Error)
    ConnectionLost = Class.new(Error)
    ConfigurationError = Class.new(Error)
    PendingOperation = Class.new(Error)
    LOCK_PATH = "/var/lock/live-deploy/global.lock".freeze

    def self.with_lock(host:, key_path:, timeout: 900)
      wait_seconds = Integer(timeout)
      unless host.to_s.match?(/\A[a-z0-9][a-z0-9.-]*\z/) && File.file?(key_path.to_s) && (0..3600).cover?(wait_seconds)
        raise ConfigurationError, "Ungültige Parameter für die Deploy-Sperre"
      end
      operation = SecureRandom.hex(16)
      program = <<~SH
        set -eu
        #{HostOperationFence.acquire_script(owner: operation)}
        printf 'LOCKED\\n'
        IFS= read -r command || exit 75
        test "$command" = 'RELEASE #{operation}' || exit 75
        #{HostOperationFence.release_script(owner: operation)}
        printf 'RELEASED\\n'
      SH
      remote = "flock -w #{wait_seconds} -E 73 #{LOCK_PATH} sh -c #{Shellwords.escape(program)}"
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
              raise PendingOperation, "Unabgeschlossene Host-Operation: #{HostOperationFence::PATH}; vor erneutem Deploy administrativ prüfen" if acknowledgement == "__LIVE_FENCED"
              raise LockTimeout, "Zeitlimit für die gemeinsame Deploy-Sperre erreicht" if waiter.value.exitstatus == 73
              raise ConnectionLost, "SSH-Deploy-Sperre konnte nicht angefordert werden"
            end
            monitor = Thread.new do
              waiter.value
              owner.raise(ConnectionLost, "SSH-Deploy-Sperre während des Vorgangs verloren") unless releasing
            end
            result = Thread.handle_interrupt(ConnectionLost => :immediate) { yield }
            # A failed CLI may have left independent SSH/Docker mutations in flight.
            unless result.is_a?(Process::Status) && !result.success?
              releasing = true
              monitor.kill
              input.puts("RELEASE #{operation}")
              input.flush
              released = begin
                Timeout.timeout(5) { output.gets&.chomp } == "RELEASED" && waiter.value.success?
              rescue Timeout::Error
                false
              end
              raise ConnectionLost, "Host-Operation wurde nicht sauber freigegeben; administrativ prüfen" unless released
            end
            result
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
    rescue Errno::EPIPE, IOError
      raise ConnectionLost, "Host-Operation unterbrochen; persistente Sperre administrativ prüfen"
    end
  end
end
