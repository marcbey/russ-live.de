require "bundler/setup"
require "kamal"
require_relative "release_support"
require_relative "deployment_remote"
require_relative "deployment_smoke"
require_relative "production_tls"
require_relative "deploy_lock"
require_relative "managed_command"
require_relative "../../app/lib/hetzner_deploy_config"

module Ops
  class ReleaseDeployment
    attr_reader :project, :peer, :repository, :remote, :destination

    def initialize(destination:, ssh_directory: File.join(Dir.home, ".ssh"))
      raise ReleaseSupport::Error, "Unbekanntes Deploy-Ziel" unless %w[staging hetzner].include?(destination)
      @destination = destination
      @ssh_directory = ssh_directory
      @repository = ReleaseSupport.repository
      @project = @repository == "marcbey/stuttgart-live.de" ? "stuttgart_live_de" : "russ_live_de"
      service = File.read("config/deploy.yml")[/^service:\s+(\w+)$/, 1]
      raise ReleaseSupport::Error, "Repository und Checkout-Service stimmen nicht überein" unless service == @project
      @peer = (DeploymentRemote::PROJECTS.keys - [ @project ]).first
    end

    def prepare!
      if destination == "staging"
        raise ReleaseSupport::Error, "Gemeinsame Secret-Datei ist in Staging verboten" if File.exist?(".kamal/secrets-common")
        %w[RAILS_MASTER_KEY MEDIA_PROXY_SECRET].each { |key| ENV[key] = required("STAGING_#{key}") }
        required("STAGING_BASIC_AUTH_HTPASSWD")
        required("STAGING_PEER_RAILS_MASTER_KEY")
        auth = required("STAGING_HTTP_AUTH").split(":", 2)
        raise ReleaseSupport::Error, "Staging-HTTP-Zugang benötigt Benutzer und Passwort" unless auth.size == 2 && auth.none?(&:empty?)
        database_keys.each { |key| ENV[key] = required("STAGING_#{key}") }
        ENV["KAMAL_SSH_PRIVATE_KEY"] = required("STAGING_SSH_PRIVATE_KEY", multiline: true)
        ENV["KAMAL_REGISTRY_PULL_PASSWORD"] = required("STAGING_KAMAL_REGISTRY_PULL_PASSWORD")
        ENV["SENTRY_AUTH_TOKEN"] = ENV.fetch("STAGING_SENTRY_AUTH_TOKEN", "")
      else
        (%w[RAILS_MASTER_KEY MEDIA_PROXY_SECRET KAMAL_REGISTRY_PULL_PASSWORD] + database_keys).each { |key| required(key) }
        required("KAMAL_SSH_PRIVATE_KEY", multiline: true)
        prepare_production_domain!
      end
      ENV["APP_ENVIRONMENT"] = destination == "staging" ? "staging" : "production"
      ENV["SENTRY_ENVIRONMENT"] = ENV.fetch("APP_ENVIRONMENT")
      ENV["KAMAL_DESTINATION"] = destination
      ENV["KAMAL_REGISTRY_PUSH_TOKEN"] = required("GH_TOKEN")
      ENV["KAMAL_SKIP_REMOTE_REGISTRY_LOGIN"] = "true"
      ENV["KAMAL_IMAGE"] = ReleaseManifest::IMAGES.fetch(repository).delete_prefix("ghcr.io/")
      directory = File.join(ENV.fetch("RUNNER_TEMP"), "live-deploy")
      FileUtils.mkdir_p(directory, mode: 0o700)
      @key_path = File.join(directory, "deploy.key")
      File.open(@key_path, "w", 0o600) { |file| file.puts ENV.fetch("KAMAL_SSH_PRIVATE_KEY") }
      host_key = HetznerDeployConfig.ssh_host_key(destination:)
      raise ReleaseSupport::Error, "Unbekannte Host-Identität" unless HetznerDeployConfig.web_host(destination:) == "46.225.224.194" && host_key.start_with?("46.225.224.194 ssh-ed25519 ")
      FileUtils.mkdir_p(@ssh_directory, mode: 0o700)
      File.open(File.join(@ssh_directory, "known_hosts"), "a", 0o600) { |file| file.puts host_key }
      ENV["KAMAL_SSH_KEY_PATH"] = @key_path
      secrets = %w[KAMAL_REGISTRY_PUSH_TOKEN KAMAL_REGISTRY_PULL_PASSWORD RAILS_MASTER_KEY MEDIA_PROXY_SECRET] + database_keys
      secrets << "STAGING_BASIC_AUTH_HTPASSWD" if destination == "staging"
      secrets.concat(%w[SSL_CERTIFICATE_PEM SSL_PRIVATE_KEY_PEM]) if destination == "hetzner" && HetznerDeployConfig.production_preissued_tls?
      File.open(".kamal/secrets.#{destination}", "w", 0o600) { |file| secrets.each { |key| file.puts "#{key}=$#{key}" } }
      @remote = DeploymentRemote.new(key_path: @key_path)
    end

    def with_lock(&block)
      DeployLock.with_lock(host: "46.225.224.194", key_path: @key_path, &block)
    end

    def deploy!(commit:, digest:)
      raise ReleaseSupport::Error, "Ungültige Release-Version" unless ReleaseManifest.sha?(commit) && digest.match?(/\Asha256:[a-f0-9]{64}\z/)
      ENV["RELEASE_DIGEST"] = digest
      ENV["SENTRY_RELEASE"] = commit
      raise ReleaseSupport::Error, "Checkout passt nicht zur Freigabe" unless ReleaseSupport.capture("git", "rev-parse", "HEAD").strip == commit
      # The read credential can pull both private packages for the paired probe.
      ReleaseSupport.capture("docker", "login", "ghcr.io", "-u", "marcbey", "--password-stdin", input: ENV.fetch("KAMAL_REGISTRY_PULL_PASSWORD"))
      @remote.capture("docker login ghcr.io -u marcbey --password-stdin", input: ENV.fetch("KAMAL_REGISTRY_PULL_PASSWORD"))
      status = ManagedCommand.run([ "mise", "exec", "--", "bin/kamal", "deploy", "-d", destination, "--skip-push", "--version", commit ])
      raise ReleaseSupport::Error, "Kamal-Deploy fehlgeschlagen; kein Proxy-Reboot und keine andere Version" unless status.success?
      config = Kamal::Configuration.create_from(config_file: "config/deploy.yml", destination:, version: commit)
      @remote.verify_running!(project:, destination:, commit:, digest:, roles: config.roles.map(&:name))
      connect_ip = HetznerDeployConfig.production_smoke_ip if destination == "hetzner"
      DeploymentSmoke.call(host: HetznerDeployConfig.app_host(destination:), staging: destination == "staging", auth: destination == "staging" ? required("STAGING_HTTP_AUTH") : nil, connect_ip:)
      puts "Image läuft geprüft: #{destination} #{commit} #{digest}"
    end

    def smoke_peer!
      host = peer == "stuttgart_live_de" ? "staging.stuttgart-live.de" : "staging.russ-live.de"
      DeploymentSmoke.call(host:, staging: true, auth: required("STAGING_HTTP_AUTH"))
    end

    def notify_sentry!
      return if ENV["SENTRY_AUTH_TOKEN"].to_s.empty?
      unless system("sh", "-c", "command -v sentry-cli >/dev/null 2>&1")
        ReleaseSupport.capture("bash", "-o", "pipefail", "-c", "curl -fsSL https://sentry.io/get-cli/ | bash")
        ENV["PATH"] = "#{File.join(Dir.home, '.local/bin')}:#{ENV.fetch('PATH')}"
      end
      if File.executable?("bin/sentry-release")
        ReleaseSupport.capture("mise", "exec", "--", "bin/sentry-release")
      else
        required("SENTRY_ORG")
        required("SENTRY_PROJECT")
        release = required("SENTRY_RELEASE")
        _, _, status = Open3.capture3("sentry-cli", "releases", "info", release)
        ReleaseSupport.capture("sentry-cli", "releases", "new", release) unless status.success?
        ReleaseSupport.capture("sentry-cli", "releases", "set-commits", "--auto", release)
        ReleaseSupport.capture("sentry-cli", "releases", "finalize", release)
        ReleaseSupport.capture("sentry-cli", "releases", "deploys", release, "new", "-e", ENV.fetch("SENTRY_ENVIRONMENT"))
      end
    end

    private

    def prepare_production_domain!
      mode = HetznerDeployConfig.production_domain_mode
      if HetznerDeployConfig.production_preissued_tls?
        ProductionTls.validate!(certificate: required("SSL_CERTIFICATE_PEM", multiline: true),
          private_key: required("SSL_PRIVATE_KEY_PEM", multiline: true), hosts: HetznerDeployConfig.production_hosts)
      end
      puts "Domainprofil: #{mode}; hosts=#{HetznerDeployConfig.production_hosts.join(',')}; redirect=#{HetznerDeployConfig.production_redirect?}; noindex=#{!HetznerDeployConfig.production_redirect?}; tls=#{HetznerDeployConfig.production_preissued_tls? ? 'preissued' : 'automatic'}"
    end

    def database_keys
      project == "stuttgart_live_de" ? %w[DB_PASSWORD] : %w[RUSS_LIVE_PRIMARY_DB_PASSWORD RUSS_LIVE_OPERATIONAL_DB_PASSWORD]
    end

    def required(key, multiline: false)
      value = ENV[key].to_s
      raise ReleaseSupport::Error, "Pflichtwert fehlt oder ist ungültig: #{key}" if value.empty? || (!multiline && value.match?(/[\r\n\0]/))
      value
    end
  end
end
