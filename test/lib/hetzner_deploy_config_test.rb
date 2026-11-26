require "test_helper"
require "tempfile"
require "support/deploy_config_helper"

class HetznerDeployConfigTest < ActiveSupport::TestCase
  include DeployConfigHelper

  test "app roles and the shared proxy use the local journal in staging and production" do
    %w[hetzner staging].each do |destination|
      raw = render_deploy_config(destination:)
      config = Kamal::Configuration.new(raw.symbolize_keys, destination:)
      config.roles.each do |role|
        assert_includes role.logging_args, '"syslog"'
        assert_includes role.logging_args, 'cache-disabled="true"'
        assert_includes role.logging_args, 'syslog-address="unixgram:///run/website-log-filter.sock"'
        assert_includes role.logging_args, 'syslog-format="rfc5424micro"'
      end
      assert_equal "", raw.dig("proxy", "run", "log_max_size")
      assert_equal "syslog", raw.dig("proxy", "run", "options", "log-driver")
      config = Kamal::Configuration.new(raw.symbolize_keys, destination:)
      proxy_command = Kamal::Commands::Proxy.new(config, host: config.primary_host).run.join(" ")
      assert_includes proxy_command, '--log-driver "syslog"'
      assert_includes proxy_command, "cache-disabled=true"
      refute_includes proxy_command, "max-size="
      assert_includes raw.dig("proxy", "run", "options", "log-opt"),
        "syslog-address=unixgram:///run/website-log-filter.sock"
      assert_includes raw.dig("proxy", "run", "options", "log-opt"), "syslog-format=rfc5424micro"
      assert_includes raw.dig("proxy", "run", "options", "log-opt"), "cache-disabled=true"
    end
  end

  test "reads shared deploy config values" do
    assert_equal "russ-live.schopp3r.de", HetznerDeployConfig.app_host
    assert_equal "46.225.224.194", HetznerDeployConfig.web_host
    assert_match(/ssh-ed25519/, HetznerDeployConfig.ssh_host_key)
  end

  test "live production includes both homepage aliases but legacy and prepared do not" do
    original = ENV["PRODUCTION_DOMAIN_MODE"]
    %w[live live_preissued].each do |mode|
      ENV["PRODUCTION_DOMAIN_MODE"] = mode
      assert_equal %w[michaelrussgmbh.de www.michaelrussgmbh.de], HetznerDeployConfig.production_homepage_redirect_hosts
      assert_equal %w[russ-live.de www.russ-live.de michaelrussgmbh.de www.michaelrussgmbh.de], HetznerDeployConfig.production_hosts
    end
    %w[legacy prepared].each do |mode|
      ENV["PRODUCTION_DOMAIN_MODE"] = mode
      assert_empty HetznerDeployConfig.production_homepage_redirect_hosts
      refute_includes HetznerDeployConfig.production_hosts, "michaelrussgmbh.de"
    end
  ensure
    ENV["PRODUCTION_DOMAIN_MODE"] = original
  end

  test "returns nil for optional app host when config is missing" do
    original_config_path = HetznerDeployConfig::CONFIG_PATH
    original_defined = HetznerDeployConfig.instance_variable_defined?(:@config)
    original_value = HetznerDeployConfig.instance_variable_get(:@config) if original_defined

    HetznerDeployConfig.send(:remove_const, :CONFIG_PATH)
    HetznerDeployConfig.const_set(:CONFIG_PATH, "/tmp/russ-live-missing-deploy-config.yml")
    HetznerDeployConfig.remove_instance_variable(:@config) if HetznerDeployConfig.instance_variable_defined?(:@config)

    assert_nil HetznerDeployConfig.app_host_if_present
  ensure
    HetznerDeployConfig.send(:remove_const, :CONFIG_PATH)
    HetznerDeployConfig.const_set(:CONFIG_PATH, original_config_path)
    HetznerDeployConfig.remove_instance_variable(:@config) if HetznerDeployConfig.instance_variable_defined?(:@config)
    HetznerDeployConfig.instance_variable_set(:@config, original_value) if original_defined
  end
end
