require "yaml"

module HetznerDeployConfig
  CONFIG_PATH = File.expand_path("../../config/deploy.hetzner.shared.yml", __dir__)
  STAGING_CONFIG_PATH = File.expand_path("../../config/deploy.staging.shared.yml", __dir__)
  MissingConfigError = Class.new(StandardError)

  class << self
    def app_host(destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"))
      key = destination == "hetzner" && production_domain_mode != "legacy" ? "canonical_app_host" : "app_host"
      fetch(key, destination:)
    end

    def app_host_if_present(destination: ENV.fetch("KAMAL_DESTINATION", "hetzner"))
      key = destination == "hetzner" && production_domain_mode != "legacy" ? "canonical_app_host" : "app_host"
      fetch(key, destination:, required: false)
    end

    def production_domain_mode
      mode = ENV.fetch("PRODUCTION_DOMAIN_MODE", "legacy")
      raise MissingConfigError, "Unknown production domain mode" unless %w[legacy prepared live_preissued live].include?(mode)
      mode
    end

    def production_hosts
      host = app_host(destination: "hetzner")
      production_domain_mode == "legacy" ? [ host ] : [ host, "www.#{host}" ]
    end

    def production_redirect?
      %w[live_preissued live].include?(production_domain_mode)
    end

    def production_preissued_tls?
      %w[prepared live_preissued].include?(production_domain_mode)
    end

    def production_smoke_ip
      web_host(destination: "hetzner") if production_preissued_tls?
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
