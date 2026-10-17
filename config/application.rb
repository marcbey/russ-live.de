require_relative "boot"
require_relative "../app/lib/deployment_environment"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RussLive
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.x.deployment_environment = DeploymentEnvironment.name(rails_env: Rails.env)
    if Rails.env.production?
      asset_build = DeploymentEnvironment.asset_build?
      DeploymentEnvironment.validate_runtime!(project: "russ_live_de") unless asset_build
      if config.x.deployment_environment == "staging"
        paths = DeploymentEnvironment.credentials_paths(root: config.root, environment: "staging")
        config.credentials.content_path = paths.fetch(:content_path)
        config.credentials.key_path = paths.fetch(:key_path)
        DeploymentEnvironment.validate_credentials!(root: config.root, environment: "staging") unless asset_build
      end
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.i18n.available_locales = %i[de en]
    config.i18n.default_locale = :de
    config.active_storage.track_variants = false
  end
end
