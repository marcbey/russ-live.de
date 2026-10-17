require "tmpdir"
require "securerandom"
require "timeout"
require "bcrypt"
require_relative "release_support"
require_relative "deployment_remote"
require_relative "../../app/lib/deployment_environment"

module Ops
  class CompatibilityProbe
    DIND = "docker:29.1.3-dind@sha256:173f284a4299164772a90f52b373e73e087583c0963f1334c9995f190ef6f3f5".freeze
    POSTGRES = "postgres:16.15@sha256:ca0bd484cb98bf4b24eb1010e73fb3fcbd6714d240fbc1a10eea5b7dbecb641d".freeze
    PROJECTS = %w[stuttgart_live_de russ_live_de].freeze

    def self.call(project:, candidate:, remote:, master_keys:)
      raise ReleaseSupport::Error, "Unbekanntes Probeprojekt" unless PROJECTS.include?(project)
      peer = (PROJECTS - [ project ]).first
      Dir.mktmpdir("live-compatibility-") do |directory|
        apps = {}
        stages = {}
        PROJECTS.each do |name|
          data_path = File.join(directory, "#{name}.jsonl")
          puts "Kompatibilität: bereinigter Staging-Export #{name}"
          stages[name] = remote.export(project: name, destination: "staging", mode: "data", path: data_path)
          encrypted = File.join(directory, "#{name}.enc")
          puts "Kompatibilität: verschlüsselte Staging-Konfiguration #{name}"
          remote.copy_from(container: stages.fetch(name).fetch("container"), source: "/rails/config/credentials/staging.yml.enc", target: encrypted)
          File.chmod(0o644, encrypted) # encrypted, mounted alone; keys stay in private env files
          apps[name] = { "data_path" => data_path, "schema_path" => data_path, "credentials_path" => encrypted,
            "master_key" => master_keys.fetch(name), "reference" => "#{stages.fetch(name).fetch('image')}@#{stages.fetch(name).fetch('digest')}" }
        end
        raise ReleaseSupport::Error, "Candidate läuft nicht in Staging" unless stages.fetch(project).fetch("commit") == candidate.fetch("commit") && stages.fetch(project).fetch("digest") == candidate.fetch("digest")
        schema_path = File.join(directory, "#{peer}-production-schema.jsonl")
        puts "Kompatibilität: schreibgeschütztes Produktionsschema #{peer}"
        production_peer = remote.export(project: peer, destination: "hetzner", mode: "schema", path: schema_path)
        apps.fetch(peer)["schema_path"] = schema_path
        apps.fetch(peer)["reference"] = "#{production_peer.fetch('image')}@#{production_peer.fetch('digest')}"
        new.run_sandbox(directory:, apps:)
        { "paired_app" => ReleaseManifest.image_identity(stages.fetch(peer)), "production_peer" => ReleaseManifest.image_identity(production_peer) }
      end
    end

    def run_sandbox(directory:, apps:)
      raise ReleaseSupport::Error, "Beide Probe-Apps erforderlich" unless apps.keys.sort == PROJECTS.sort
      @daemon = "live-compatibility-#{SecureRandom.hex(8)}"
      @aliases = []
      puts "Kompatibilität: isolierten Docker-Prüfserver starten"
      pull(DIND)
      ReleaseSupport.capture("docker", "run", "--detach", "--rm", "--privileged", "--network", "none", "--name", @daemon,
        "--memory", "3g", "--cpus", "2", "--env", "DOCKER_TLS_CERTDIR=", DIND, "--storage-driver=overlay2", "--iptables=false")
      wait_for_daemon
      puts "Kompatibilität: isolierter Docker-Prüfserver bereit"
      disconnected = JSON.parse(ReleaseSupport.capture("docker", "inspect", "--format", "{{json .HostConfig.NetworkMode}}", @daemon))
      raise ReleaseSupport::Error, "Prüfserver besitzt externes Netzwerk" unless disconnected == "none"
      image_aliases = apps.to_h { |project, settings| [ project, load_image(settings.fetch("reference"), project) ] }
      postgres_alias = load_image(POSTGRES, "postgres")
      inner("network", "create", "--internal", "--subnet", "172.18.0.0/16", "kamal")
      inner("volume", "create", "stuttgart_live_de_staging_storage")
      puts "Kompatibilität: isolierte Eingaben und PostgreSQL vorbereiten"
      input = prepare_files(directory, apps, image_aliases)
      inner("run", "--detach", "--name", "postgres", "--network", "host", "--memory", "512m",
        "--env-file", "/probe/postgres.env", postgres_alias, "-c", "live.compatibility_sandbox=on")
      Timeout.timeout(90) do
        loop do
          break if system_inner("exec", "postgres", "pg_isready", "-h", "127.0.0.1", "-U", "postgres")
          sleep 1
        end
      end
      create_databases(input)
      PROJECTS.each do |project|
        puts "Kompatibilität: isolierte Schema-/Datenkopie #{project}"
        inner("run", "--rm", "--user", "0:0", "--network", "kamal", "--mount", "type=bind,src=/probe,dst=/probe,readonly",
          "--entrypoint", "bundle", image_aliases.fetch(project), "exec", "ruby", "/probe/compatibility_load.rb", project)
      end
      write_readiness(image_aliases.values.first)
      PROJECTS.each do |project|
        inner("run", "--detach", "--name", project, "--network", "kamal", "--memory", "768m", "--cpus", "0.5",
          "--env-file", "/probe/#{project}.env", "--mount", "type=volume,src=stuttgart_live_de_staging_storage,dst=/rails/storage",
          "--mount", "type=bind,src=/probe/#{project}.enc,dst=/rails/config/credentials/staging.yml.enc,readonly",
          "--mount", "type=bind,src=/probe/#{project}.enc,dst=/rails/config/credentials.yml.enc,readonly", image_aliases.fetch(project))
      end
      PROJECTS.each do |project|
        puts "Kompatibilität: HTTP und gemeinsame Anmeldung #{project}"
        probe_app(project)
      end
      true
    ensure
      if @daemon
        Open3.capture3("docker", "rm", "--force", "--volumes", @daemon)
        @aliases&.each { |name| Open3.capture3("docker", "image", "rm", name) }
      end
    end

    private

    def pull(reference)
      return if reference.match?(/\Asha256:[a-f0-9]{64}\z/) # local immutable fixture image ID
      ReleaseSupport.capture("docker", "pull", reference)
    end

    def inner(*arguments, input: nil)
      ReleaseSupport.capture("docker", "exec", "--interactive", @daemon, "docker", *arguments, input:)
    end

    def system_inner(*arguments)
      _, _, status = Open3.capture3("docker", "exec", @daemon, "docker", *arguments)
      status.success?
    end

    def wait_for_daemon
      Timeout.timeout(90) do
        loop do
          break if system_inner("info")
          sleep 1
        end
      end
    end

    def load_image(reference, role)
      puts "Kompatibilität: Registry-Image #{role} laden"
      pull(reference)
      name = "#{@daemon}-#{role}:input"
      source = JSON.parse(ReleaseSupport.capture("docker", "image", "inspect", reference)).first
      fingerprint = ImageFingerprint.call(source)
      ReleaseSupport.capture("docker", "tag", reference, name)
      @aliases << name
      # Load only locally verified image bytes: the nested daemon has no registry access.
      puts "Kompatibilität: Image #{role} isoliert übertragen"
      Open3.pipeline([ "docker", "save", name ], [ "docker", "exec", "--interactive", @daemon, "docker", "load" ], out: File::NULL, err: File::NULL).each do |status|
        raise ReleaseSupport::Error, "Prüfimage konnte nicht isoliert geladen werden" unless status.success?
      end
      puts "Kompatibilität: Laufzeitidentität #{role} prüfen"
      loaded = JSON.parse(inner("image", "inspect", name)).first
      raise ReleaseSupport::Error, "Image-Identität beim Laden verändert" unless ImageFingerprint.call(loaded) == fingerprint
      name
    end

    def prepare_files(directory, apps, aliases)
      passwords = %w[postgres stuttgart_live_de_staging russ_live_de_staging russ_live_de_staging_reader].to_h { |role| [ role, SecureRandom.hex(32) ] }
      admin_password = SecureRandom.hex(24)
      media_secret = SecureRandom.hex(32)
      auth = "probe:#{SecureRandom.hex(24)}"
      hash = "probe:#{BCrypt::Password.create(auth.split(':', 2).last, cost: BCrypt::Engine::MIN_COST)}"
      inputs = { "apps" => {}, "postgres_password" => passwords.fetch("postgres"), "passwords" => passwords, "admin_password" => admin_password }
      PROJECTS.each do |project|
        settings = apps.fetch(project)
        data_name = "#{project}.jsonl"
        schema_name = settings.fetch("schema_path") == settings.fetch("data_path") ? data_name : "#{project}-production-schema.jsonl"
        FileUtils.cp(settings.fetch("data_path"), File.join(directory, data_name)) unless File.expand_path(settings.fetch("data_path")) == File.join(directory, data_name)
        FileUtils.cp(settings.fetch("schema_path"), File.join(directory, schema_name)) unless File.expand_path(settings.fetch("schema_path")) == File.join(directory, schema_name)
        encrypted = File.join(directory, "#{project}.enc")
        FileUtils.cp(settings.fetch("credentials_path"), encrypted) unless File.expand_path(settings.fetch("credentials_path")) == encrypted
        File.chmod(0o644, encrypted)
        inputs.fetch("apps")[project] = { "data_path" => "/probe/#{data_name}", "schema_path" => "/probe/#{schema_name}" }
        env = DeploymentEnvironment.staging_profile(project:).merge("RAILS_ENV" => "production", "APP_ENVIRONMENT" => "staging",
          "RAILS_MASTER_KEY" => settings.fetch("master_key"), "MEDIA_PROXY_SECRET" => media_secret, "STAGING_BASIC_AUTH_HTPASSWD" => hash,
          "WEB_CONCURRENCY" => "1", "RAILS_MAX_THREADS" => "2", "DB_POOL" => "2", "QUEUE_DB_POOL" => "2",
          "PROBE_HTTP_AUTH" => auth, "PROBE_ADMIN_PASSWORD" => admin_password)
        if project == "stuttgart_live_de"
          env["DB_PASSWORD"] = passwords.fetch("stuttgart_live_de_staging")
        else
          env["RUSS_LIVE_PRIMARY_DB_PASSWORD"] = passwords.fetch("russ_live_de_staging_reader")
          env["RUSS_LIVE_OPERATIONAL_DB_PASSWORD"] = passwords.fetch("russ_live_de_staging")
        end
        write_env(File.join(directory, "#{project}.env"), env)
      end
      write_env(File.join(directory, "postgres.env"), "POSTGRES_PASSWORD" => passwords.fetch("postgres"))
      ReleaseSupport.write_json(File.join(directory, "input.json"), inputs)
      %w[compatibility_copy.rb compatibility_load.rb].each { |name| FileUtils.cp(File.join(__dir__, name), directory) }
      ReleaseSupport.capture("docker", "exec", @daemon, "mkdir", "-m", "0700", "/probe")
      ReleaseSupport.capture("docker", "cp", "#{directory}/.", "#{@daemon}:/probe")
      # Keep the aliases parameter explicit for callers' auditable image mapping.
      raise ReleaseSupport::Error, "Unvollständige Image-Zuordnung" unless aliases.keys.sort == PROJECTS.sort
      inputs
    end

    def write_env(path, env)
      raise ReleaseSupport::Error, "Ungültiger mehrzeiliger Probe-Wert" if env.values.any? { |value| value.to_s.match?(/[\r\n\0]/) }
      File.open(path, "w", 0o600) { |file| env.each { |key, value| file.puts "#{key}=#{value}" } }
    end

    def create_databases(input)
      statements = input.fetch("passwords").except("postgres").map do |role, password|
        "CREATE ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '#{password}';"
      end
      PROJECTS.each do |project|
        [ "", "_cache", "_queue", "_cable" ].each do |suffix|
          statements << "CREATE DATABASE #{project}_staging#{suffix} OWNER #{project}_staging;"
        end
      end
      inner("exec", "--interactive", "postgres", "psql", "--no-psqlrc", "--set", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "postgres", input: statements.join("\n"))
    end

    def write_readiness(image)
      marker = { schema_version: 1, environment: "staging", volume: "stuttgart_live_de_staging_storage", refresh_id: "compatibility-#{SecureRandom.hex(8)}",
        databases: PROJECTS.to_h { |project| [ project, "#{project}_staging" ] } }
      code = "require 'json'; root='/rails/storage'; File.chown(1000,1000,root); File.chmod(0750,root); File.write(root+'/.staging-ready.json', #{JSON.generate(marker).inspect}, perm: 0640); File.chown(1000,1000,root+'/.staging-ready.json')"
      inner("run", "--rm", "--user", "0:0", "--network", "none", "--mount", "type=volume,src=stuttgart_live_de_staging_storage,dst=/rails/storage", "--entrypoint", "ruby", image, "-e", code)
    end

    def probe_app(project)
      code = <<~'RUBY'
        require "net/http"
        request = Net::HTTP::Get.new("/")
        request["Host"] = ENV.fetch("APP_HOST")
        request["X-Forwarded-Proto"] = "https"
        request.basic_auth(*ENV.fetch("PROBE_HTTP_AUTH").split(":", 2))
        response = Net::HTTP.new("127.0.0.1", 80, nil).start { |http| http.request(request) }
        exit(response.code == "200" && response["x-request-id"] && response.body.bytesize > 200 ? 0 : 1)
      RUBY
      Timeout.timeout(180) do
        loop do
          break if system_inner("exec", project, "ruby", "-e", code)
          sleep 2
        end
      end
      auth = "abort 'Gemeinsame Anmeldung fehlgeschlagen' unless User.find_by(email_address: 'probe-admin@example.invalid')&.authenticate(ENV.fetch('PROBE_ADMIN_PASSWORD'))"
      inner("exec", "--interactive", project, "./bin/rails", "runner", "-", input: auth)
    end
  end
end
