require "yaml"

module HetznerDeployConfig
  CONFIG_PATH = File.expand_path("../../config/deploy.hetzner.shared.yml", __dir__)
  MissingConfigError = Class.new(StandardError)

  class << self
    def app_host
      fetch("app_host")
    end

    def app_host_if_present
      fetch("app_host", required: false)
    end

    def web_host
      fetch("web_host")
    end

    def ssh_host_key
      fetch("ssh_host_key")
    end

    def fetch(key, required: true)
      loaded_config = config(required:)
      return unless loaded_config

      loaded_config.fetch(key)
    end

    private

    def config(required: true)
      return @config if instance_variable_defined?(:@config)

      unless File.exist?(config_path)
        if required
          raise MissingConfigError, "Missing Hetzner deploy config at #{config_path}"
        end

        @config = nil
        return
      end

      @config = YAML.safe_load_file(config_path) || {}
    end

    def config_path
      CONFIG_PATH
    end
  end
end
