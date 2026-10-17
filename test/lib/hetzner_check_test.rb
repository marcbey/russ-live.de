require "test_helper"
require "open3"

class HetznerCheckTest < ActiveSupport::TestCase
  test "staging check resolves its own secrets without loading a production env" do
    with_check_root do |root, env|
      File.write(root.join(".env"), "exit 23\n")
      output, status = run_check(root, env)
      assert status.success?, output
      assert_includes output, "Status: OK"
      refute_includes output, "stage-secret-value"
    end
  end

  test "staging check rejects missing secret values and common secrets" do
    with_check_root do |root, env|
      output, status = run_check(root, env.merge("MEDIA_PROXY_SECRET" => nil))
      refute status.success?
      assert_includes output, "MEDIA_PROXY_SECRET"
      refute_includes output, "stage-secret-value"
      File.write(root.join(".kamal/secrets-common"), "DB_PASSWORD=production-secret\n")
      output, status = run_check(root, env)
      refute status.success?
      assert_includes output, "secrets-common"
      refute_includes output, "production-secret"
    end
  end

  private

  def run_check(root, env)
    Open3.capture2e(env, "bash", root.join("bin/hetzner-check").to_s, "--destination", "staging")
  end

  def with_check_root
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      %w[bin app/lib config/credentials .kamal .ssh].each { |name| FileUtils.mkdir_p(root.join(name)) }
      %w[bin/hetzner-check app/lib/deployment_environment.rb app/lib/hetzner_deploy_config.rb config/deploy.staging.yml config/deploy.staging.shared.yml].each do |name|
        FileUtils.cp(Rails.root.join(name), root.join(name))
      end
      File.write(root.join("config/credentials/staging.yml.enc"), "fixture")
      File.write(root.join(".ssh/stgt-live-hetzner-github"), "fixture")
      names = File.read(Rails.root.join(".kamal/secrets.staging.example")).lines.filter_map { |line| line[/^([A-Z_]+)=/, 1] }
      FileUtils.cp(Rails.root.join(".kamal/secrets.staging.example"), root.join(".kamal/secrets.staging"))
      env = names.index_with { "stage-secret-value" }.merge("HOME" => root.to_s, "SENTRY_RELEASE" => "test-release")
      yield root, env
    end
  end
end
