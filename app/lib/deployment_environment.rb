require "pathname"

# Rails stays in production mode; deployment profiles isolate operational resources.
module DeploymentEnvironment
  ConfigurationError = Class.new(StandardError)
  PROJECTS = %w[stuttgart_live_de russ_live_de].freeze

  class << self
    def name(env: ENV, rails_env: ENV.fetch("RAILS_ENV", "development"))
      return rails_env unless rails_env == "production"

      value = env["APP_ENVIRONMENT"].to_s
      return value if %w[production staging].include?(value)
      return "build" if value.empty? && env["SECRET_KEY_BASE_DUMMY"] == "1"

      raise ConfigurationError, "APP_ENVIRONMENT must be production or staging"
    end

    def asset_build?(env: ENV, argv: ARGV)
      tasks = argv
      tasks = Rake.application.top_level_tasks if tasks.empty? && defined?(Rake)
      env["SECRET_KEY_BASE_DUMMY"] == "1" && tasks == [ "assets:precompile" ]
    end

    def credentials_paths(root:, environment:)
      root = Pathname.new(root)
      if environment == "staging"
        { content_path: root.join("config/credentials/staging.yml.enc"), key_path: root.join("config/credentials/staging.key") }
      else
        { content_path: root.join("config/credentials.yml.enc"), key_path: root.join("config/master.key") }
      end
    end

    def validate_credentials!(root:, environment:, env: ENV)
      return true unless environment == "staging"

      paths = credentials_paths(root:, environment:)
      raise ConfigurationError, "Staging credentials file missing" unless paths.fetch(:content_path).file?
      unless !env["RAILS_MASTER_KEY"].to_s.empty? || paths.fetch(:key_path).file?
        raise ConfigurationError, "Staging credentials key missing"
      end
      true
    end

    def staging_profile(project:)
      raise ConfigurationError, "Unknown project" unless PROJECTS.include?(project)

      operational = "#{project}_staging"
      profile = {
        "SOLID_QUEUE_SKIP_RECURRING" => "true",
        "APP_HOST" => (project == "stuttgart_live_de" ? "staging.stuttgart-live.de" : "staging.russ-live.de"),
        "APP_ALLOWED_HOSTS" => (project == "stuttgart_live_de" ? "staging.stuttgart-live.de" : "staging.russ-live.de"),
        "CANONICAL_REDIRECT_ENABLED" => "false", "STAGING_NOINDEX" => "true",
        "DB_HOST" => "172.18.0.1", "DB_PORT" => "5432",
        "DB_NAME" => "stuttgart_live_de_staging",
        "DB_USER" => "stuttgart_live_de_staging",
        "CACHE_DB_NAME" => "#{operational}_cache", "QUEUE_DB_NAME" => "#{operational}_queue",
        "CABLE_DB_NAME" => "#{operational}_cable", "ACTIVE_STORAGE_SERVICE" => "local",
        "ACTIVE_STORAGE_ROOT" => "/rails/storage", "STORAGE_VOLUME" => "stuttgart_live_de_staging_storage"
      }
      if project == "russ_live_de"
        profile.merge!("DB_USER" => "russ_live_de_staging_reader", "OPERATIONAL_DB_USER" => operational,
          "RUSS_DB_NAME" => operational)
      end
      profile.freeze
    end

    def staging_smtp_settings
      { address: "stuttgart_live_de-staging-mailpit", port: 1025, enable_starttls_auto: false }
    end

    def validate_runtime!(env: ENV, project:)
      raise ConfigurationError, "Unknown project" unless PROJECTS.include?(project)
      raise ConfigurationError, "SECRET_KEY_BASE_DUMMY is only permitted for asset builds" if env["SECRET_KEY_BASE_DUMMY"] == "1"
      return true unless name(env:, rails_env: "production") == "staging"

      env.each_key do |key|
        if key == "DATABASE_URL" || key.end_with?("_DATABASE_URL")
          raise ConfigurationError, "#{key} is forbidden in staging"
        end
      end
      staging_profile(project:).each do |key, expected|
        raise ConfigurationError, "Invalid staging configuration: #{key}" unless env[key].to_s == expected
      end
      true
    end
  end
end
