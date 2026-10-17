module Ops
  module HostOperationFence
    PATH = "/var/lock/live-deploy/active-operation".freeze

    def self.acquire_script(owner:)
      validate_owner!(owner)
      <<~SH
        if [ -e #{PATH} ] || [ -L #{PATH} ]; then
          printf '__LIVE_FENCED\\n'
          exit 74
        fi
        umask 077
        mkdir #{PATH}
        printf '%s\\n' '#{owner}' > #{PATH}/owner
      SH
    end

    def self.release_script(owner:)
      validate_owner!(owner)
      <<~SH
        test "$(cat #{PATH}/owner)" = '#{owner}'
        rm #{PATH}/owner
        rmdir #{PATH}
      SH
    end

    def self.validate_owner!(owner)
      raise ArgumentError, "Ungültige Operationskennung" unless owner.match?(/\A[a-f0-9]{32}\z/)
    end
  end
end
