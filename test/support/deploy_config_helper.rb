require "kamal"
require "pathname"

module DeployConfigHelper
  def render_deploy_config(destination:)
    original_env = ENV.to_h
    ENV.replace("PATH" => original_env.fetch("PATH"), "HOME" => original_env.fetch("HOME"),
      "KAMAL_DESTINATION" => destination, "SENTRY_RELEASE" => "test-release")
    raw = Kamal::Configuration.load_raw_config(config_file: Rails.root.join("config/deploy.yml"), destination:)
    Kamal::Configuration.new(raw, destination:)
    raw.deep_stringify_keys
  ensure
    ENV.replace(original_env)
  end
end
