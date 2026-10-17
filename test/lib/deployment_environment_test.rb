require "test_helper"
require "open3"
require "rake"
require "support/deploy_config_helper"

class DeploymentEnvironmentTest < ActiveSupport::TestCase
  include DeployConfigHelper

  setup { assert defined?(DeploymentEnvironment), "DeploymentEnvironment must be loaded before credentials" }

  test "requires an explicit deployment profile in Rails production" do
    assert_equal "staging", DeploymentEnvironment.name(env: { "APP_ENVIRONMENT" => "staging" }, rails_env: "production")
    assert_equal "production", DeploymentEnvironment.name(env: { "APP_ENVIRONMENT" => "production" }, rails_env: "production")
    [ {}, { "APP_ENVIRONMENT" => "prod" } ].each do |env|
      assert_raises(DeploymentEnvironment::ConfigurationError) { DeploymentEnvironment.name(env:, rails_env: "production") }
    end
    assert_equal "test", DeploymentEnvironment.name(env: {}, rails_env: "test")
    assert_equal "development", DeploymentEnvironment.name(env: {}, rails_env: "development")
  end

  test "asset builds do not override staging or permit dummy runtime keys" do
    dummy = { "SECRET_KEY_BASE_DUMMY" => "1" }
    assert_equal "build", DeploymentEnvironment.name(env: dummy, rails_env: "production")
    assert_equal "staging", DeploymentEnvironment.name(env: dummy.merge("APP_ENVIRONMENT" => "staging"), rails_env: "production")
    assert DeploymentEnvironment.asset_build?(env: dummy, argv: [ "assets:precompile" ])
    refute DeploymentEnvironment.asset_build?(env: dummy, argv: [ "server" ])
    Rake.with_application do |rake|
      rake.init("rails", [ "assets:precompile" ])
      assert DeploymentEnvironment.asset_build?(env: dummy, argv: [])
    end
    Rake.with_application do |rake|
      rake.init("rails", [ "assets:precompile", "db:migrate" ])
      refute DeploymentEnvironment.asset_build?(env: dummy, argv: [])
    end
    assert_raises(DeploymentEnvironment::ConfigurationError) do
      DeploymentEnvironment.validate_runtime!(env: stage_env.merge(dummy), project: project)
    end
  end

  test "staging credentials never use the production master key path" do
    paths = DeploymentEnvironment.credentials_paths(root: Rails.root, environment: "staging")
    assert_equal Rails.root.join("config/credentials/staging.yml.enc"), paths.fetch(:content_path)
    assert_equal Rails.root.join("config/credentials/staging.key"), paths.fetch(:key_path)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      File.write(File.join(root, "config/master.key"), "production key")
      assert_raises(DeploymentEnvironment::ConfigurationError) do
        DeploymentEnvironment.validate_credentials!(root:, environment: "staging", env: {})
      end
      FileUtils.mkdir_p(File.join(root, "config/credentials"))
      File.write(File.join(root, "config/credentials/staging.yml.enc"), "encrypted")
      assert_raises(DeploymentEnvironment::ConfigurationError) do
        DeploymentEnvironment.validate_credentials!(root:, environment: "staging", env: {})
      end
      assert DeploymentEnvironment.validate_credentials!(root:, environment: "staging", env: { "RAILS_MASTER_KEY" => "stage-key" })
    end
  end

  test "staging rejects every production database role volume and URL override without revealing values" do
    assert DeploymentEnvironment.validate_runtime!(env: stage_env, project: project)
    assert_raises(DeploymentEnvironment::ConfigurationError) do
      DeploymentEnvironment.validate_runtime!(env: stage_env.merge("SOLID_QUEUE_SKIP_RECURRING" => "false"), project: project)
    end
    DeploymentEnvironment.staging_profile(project:).each_key do |key|
      error = assert_raises(DeploymentEnvironment::ConfigurationError, key) do
        DeploymentEnvironment.validate_runtime!(env: stage_env.merge(key => "unsafe-secret-value"), project: project)
      end
      assert_includes error.message, key
      refute_includes error.message, "unsafe-secret-value"
    end
    assert_raises(DeploymentEnvironment::ConfigurationError) do
      DeploymentEnvironment.validate_runtime!(env: stage_env.merge("APP_HOST" => "production.example"), project: project)
    end
    %w[DATABASE_URL PRIMARY_DATABASE_URL RUSS_DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL].each do |key|
      error = assert_raises(DeploymentEnvironment::ConfigurationError) do
        DeploymentEnvironment.validate_runtime!(env: stage_env.merge(key => "postgres://private:password@production/db"), project: project)
      end
      assert_includes error.message, key
      refute_includes error.message, "password"
    end
    assert_raises(DeploymentEnvironment::ConfigurationError) do
      DeploymentEnvironment.validate_runtime!(env: stage_env, project: "misspelled")
    end
  end

  test "Kamal renders isolated stage and unchanged production destinations in alternating order" do
    stage = render_deploy_config(destination: "staging")
    production = render_deploy_config(destination: "hetzner")
    assert_equal "staging", stage.dig("env", "clear", "APP_ENVIRONMENT")
    assert_equal "production", production.dig("env", "clear", "APP_ENVIRONMENT")
    assert_equal "stuttgart_live_de_staging", stage.dig("env", "clear", "DB_NAME")
    assert_equal [ "stuttgart_live_de_staging_storage:/rails/storage" ], stage.fetch("volumes")
    assert_equal [ "stuttgart_live_de_storage:/rails/storage" ], production.fetch("volumes")
    assert_equal "staging.russ-live.de", stage.dig("proxy", "host")
    assert_equal "russ-live.schopp3r.de", production.dig("proxy", "host")
    assert_equal stage, render_deploy_config(destination: "staging")
    assert_equal "768m", stage.dig("servers", "web", "options", "memory")
    assert_equal "512m", stage.dig("servers", "job", "options", "memory")
    DeploymentEnvironment.validate_runtime!(env: stage.fetch("env").fetch("clear").transform_values(&:to_s), project: project)
    assert_raises(HetznerDeployConfig::MissingConfigError) { HetznerDeployConfig.app_host(destination: "unknown") }
  end

  test "production boot rejects wrong profiles and overrides before accessing credentials or databases" do
    cases = [
      [ { "APP_ENVIRONMENT" => nil }, "APP_ENVIRONMENT" ],
      [ stage_env.merge("DATABASE_URL" => "postgres://private:private-password@production/db"), "DATABASE_URL" ],
      [ stage_env.merge("SECRET_KEY_BASE_DUMMY" => "1"), "SECRET_KEY_BASE_DUMMY" ]
    ]
    cases.each do |env, expected|
      output, status = Open3.capture2e(env.merge("RAILS_ENV" => "production"), "mise", "exec", "--", "bin/rails", "runner", "abort 'Unexpected successful boot'", chdir: Rails.root)
      refute status.success?
      assert_includes output, expected
      refute_includes output, "private-password"
    end
  end

  private

  def project
    "russ_live_de"
  end

  def stage_env
    DeploymentEnvironment.staging_profile(project:).merge("APP_ENVIRONMENT" => "staging")
  end
end
