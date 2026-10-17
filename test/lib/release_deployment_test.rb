require "test_helper"
require "open3"

class ReleaseDeploymentTest < ActiveSupport::TestCase
  test "stage uses its explicit prefixed secrets and never inherited production values" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, ".kamal"))
      FileUtils.mkdir_p(File.join(root, "config"))
      File.write(File.join(root, "config/deploy.yml"), "service: russ_live_de\n")
      env = {
        "GITHUB_REPOSITORY" => "marcbey/russ-live.de", "GH_TOKEN" => "test-registry-token", "RUNNER_TEMP" => root,
        "STAGING_RAILS_MASTER_KEY" => "s" * 32, "STAGING_MEDIA_PROXY_SECRET" => "m" * 64,
        "STAGING_PEER_RAILS_MASTER_KEY" => "p" * 32, "STAGING_HTTP_AUTH" => "stage:synthetic-password",
        "STAGING_RUSS_LIVE_OPERATIONAL_DB_PASSWORD" => "d" * 32, "STAGING_RUSS_LIVE_PRIMARY_DB_PASSWORD" => "p" * 32, "STAGING_BASIC_AUTH_HTPASSWD" => "stage:synthetic-test-hash",
        "STAGING_SSH_PRIVATE_KEY" => "synthetic-key\n", "STAGING_KAMAL_REGISTRY_PULL_PASSWORD" => "test-pull-token",
        "RAILS_MASTER_KEY" => "INHERITED_PRODUCTION", "RUSS_LIVE_OPERATIONAL_DB_PASSWORD" => "INHERITED_PRODUCTION", "MEDIA_PROXY_SECRET" => "INHERITED_PRODUCTION"
      }
      code = <<~'RUBY'
        require ARGV.shift
        root = ARGV.shift
        Dir.chdir(root)
        deployment = Ops::ReleaseDeployment.new(destination: 'staging', ssh_directory: File.join(root, 'ssh'))
        deployment.prepare!
        abort 'wrong key' unless ENV.fetch('RAILS_MASTER_KEY') == ENV.fetch('STAGING_RAILS_MASTER_KEY')
        abort 'wrong db' unless ENV.fetch('RUSS_LIVE_OPERATIONAL_DB_PASSWORD') == ENV.fetch('STAGING_RUSS_LIVE_OPERATIONAL_DB_PASSWORD')
        abort 'wrong auth' unless ENV.fetch('STAGING_BASIC_AUTH_HTPASSWD') == 'stage:synthetic-test-hash'
        abort 'wrong profile' unless ENV.fetch('APP_ENVIRONMENT') == 'staging'
        abort 'secret file mode' unless (File.stat('.kamal/secrets.staging').mode & 0777) == 0600
      RUBY
      script = Rails.root.join("script/ops/deploy_release.rb").to_s
      out, err, status = Open3.capture3(env, "mise", "exec", "--", "bundle", "exec", "ruby", "-e", code, script, root)
      assert status.success?, out + err
      assert_not_includes out + err, "INHERITED_PRODUCTION"
    end
  end

  test "repository and checkout service cannot address different projects" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      File.write(File.join(root, "config/deploy.yml"), "service: russ_live_de\n")
      code = <<~'RUBY'
        require ARGV.shift
        Dir.chdir(ARGV.shift)
        begin
          Ops::ReleaseDeployment.new(destination: 'staging')
        rescue Ops::ReleaseSupport::Error
          exit 0
        end
        abort 'Fremdes Repository wurde akzeptiert'
      RUBY
      env = { "GITHUB_REPOSITORY" => "marcbey/stuttgart-live.de" }
      out, err, status = Open3.capture3(env, "mise", "exec", "--", "bundle", "exec", "ruby", "-e", code, Rails.root.join("script/ops/deploy_release.rb").to_s, root)
      assert status.success?, out + err
    end
  end
end
