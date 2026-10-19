require "test_helper"
require "tempfile"

class HetznerDeployConfigTest < ActiveSupport::TestCase
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
