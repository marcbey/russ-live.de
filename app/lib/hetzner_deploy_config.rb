require "yaml"

module HetznerDeployConfig
  CONFIG_PATH = File.expand_path("../../config/deploy.hetzner.shared.yml", __dir__)
  STAGING_CONFIG_PATH = File.expand_path("../../config/deploy.staging.shared.yml", __dir__)
  MissingConfigError = Class.new(StandardError)

  class << self
    def app_host(destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"))
      fetch("app_host", destination:)
    end

    def app_host_if_present(destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"))
      fetch("app_host", destination:, required: false)
    end

    def web_host(destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"))
      fetch("web_host", destination:)
    end

    def ssh_host_key(destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"))
      fetch("ssh_host_key", destination:)
    end

    def fetch(key, destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"), required: true)
      path = case destination
      when "hetzner" then config_path
      when "staging" then STAGING_CONFIG_PATH
      else raise MissingConfigError, "Unknown deploy destination"
      end
      unless File.file?(path)
        raise MissingConfigError, "Missing Hetzner deploy config at #{path}" if required
        return
      end
      @config ||= {}
      config = @config[[ destination, path ]] ||= YAML.safe_load_file(path) || {}
      value = config[key]
      raise MissingConfigError, "Missing Hetzner deploy config value: #{key}" if required && value.to_s.empty?
      value
    end

    private

    def config_path
      CONFIG_PATH
    end
  end
end
