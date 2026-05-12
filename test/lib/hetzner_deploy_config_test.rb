require "test_helper"
require "tempfile"

class HetznerDeployConfigTest < ActiveSupport::TestCase
  test "reads shared deploy config values" do
    assert_equal "russ-live.schopp3r.de", HetznerDeployConfig.app_host
    assert_equal "46.225.224.194", HetznerDeployConfig.web_host
    assert_match(/ssh-ed25519/, HetznerDeployConfig.ssh_host_key)
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
