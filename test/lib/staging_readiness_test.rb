require "test_helper"
require "tmpdir"
require "json"
require "open3"
require_relative "../../app/lib/staging_readiness"

class StagingReadinessTest < ActiveSupport::TestCase
  test "stage web and jobs require a complete matching readiness file" do
    Dir.mktmpdir do |root|
      env = DeploymentEnvironment.staging_profile(project: "russ_live_de").merge("APP_ENVIRONMENT" => "staging", "RAILS_ENV" => "production")
      assert_raises(StagingReadiness::Error) { StagingReadiness.verify!(project: "russ_live_de", env:, root:) }
      marker = { "schema_version" => 1, "environment" => "staging", "volume" => "stuttgart_live_de_staging_storage",
        "databases" => { "stuttgart_live_de" => "stuttgart_live_de_staging", "russ_live_de" => "russ_live_de_staging" }, "refresh_id" => "20261017-test01" }
      path = File.join(root, ".staging-ready.json")
      File.write(path, marker.to_json, mode: "w", perm: 0o640)
      assert StagingReadiness.verify!(project: "russ_live_de", env:, root:)
      marker["databases"]["stuttgart_live_de"] = "stuttgart_live_de_production"
      File.write(path, marker.to_json)
      assert_raises(StagingReadiness::Error) { StagingReadiness.verify!(project: "russ_live_de", env:, root:) }
      assert_raises(DeploymentEnvironment::ConfigurationError) { StagingReadiness.verify!(project: "russ_live_de", env: env.merge("DB_NAME" => "stuttgart_live_de_production"), root:) }
    end
  end

  test "production has no dependency on a staging readiness file" do
    assert StagingReadiness.verify!(project: "russ_live_de", env: { "APP_ENVIRONMENT" => "production", "RAILS_ENV" => "production" }, root: "/does-not-exist")
  end

  test "direct web and worker commands refuse unready stage before credentials or database boot" do
    env = DeploymentEnvironment.staging_profile(project: "russ_live_de").merge("APP_ENVIRONMENT" => "staging", "RAILS_ENV" => "production", "RAILS_MASTER_KEY" => nil, "SECRET_KEY_BASE_DUMMY" => nil)
    [ [ "bin/jobs" ], [ "bin/rails", "server" ], [ "bin/production-server" ], [ "bin/docker-entrypoint", "./bin/production-server" ] ].each do |command|
      _out, err, status = Open3.capture3(env, "mise", "exec", "--", *command)
      assert_not status.success?, command.inspect
      assert_includes err, "Staging benötigt einen abgeschlossenen bereinigten Refresh"
      assert_not_includes err, "Missing encryption key"
    end
  end
end
