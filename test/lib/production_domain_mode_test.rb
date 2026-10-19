require "test_helper"
require "support/deploy_config_helper"

class ProductionDomainModeTest < ActiveSupport::TestCase
  include DeployConfigHelper

  test "domain preparation and cutover change only documented runtime values" do
    %w[prepared live_preissued live].each do |mode|
      config = render_deploy_config(destination: "hetzner", env: { "PRODUCTION_DOMAIN_MODE" => mode })
      clear = config.fetch("env").fetch("clear")
      assert_equal "russ-live.de", clear.fetch("APP_HOST")
      aliases = mode == "prepared" ? [] : %w[michaelrussgmbh.de www.michaelrussgmbh.de]
      hosts = %w[russ-live.de www.russ-live.de] + aliases
      assert_equal hosts.join(","), clear.fetch("APP_ALLOWED_HOSTS")
      assert_equal aliases.join(","), clear.fetch("HOMEPAGE_REDIRECT_HOSTS")
      assert_equal mode != "prepared", clear.fetch("CANONICAL_REDIRECT_ENABLED").to_s == "true"
      assert_equal mode == "prepared", clear.fetch("STAGING_NOINDEX").to_s == "true"
      assert_equal hosts, config.fetch("proxy").fetch("hosts")
      expected = mode == "live" ? true : { "certificate_pem" => "SSL_CERTIFICATE_PEM", "private_key_pem" => "SSL_PRIVATE_KEY_PEM" }
      assert_equal expected, config.fetch("proxy").fetch("ssl")
    end
  end

  test "invalid production modes fail and never weaken staging" do
    assert_raises(HetznerDeployConfig::MissingConfigError) do
      render_deploy_config(destination: "hetzner", env: { "PRODUCTION_DOMAIN_MODE" => "typo" })
    end
    assert_equal render_deploy_config(destination: "staging"), render_deploy_config(destination: "staging", env: { "PRODUCTION_DOMAIN_MODE" => "live" })
  end

  test "both preissued modes can be verified before the public DNS cutover" do
    original = ENV["PRODUCTION_DOMAIN_MODE"]
    %w[legacy prepared live_preissued live].each do |mode|
      ENV["PRODUCTION_DOMAIN_MODE"] = mode
      expected = %w[prepared live_preissued].include?(mode) ? "46.225.224.194" : nil
      expected ? assert_equal(expected, HetznerDeployConfig.production_smoke_ip) : assert_nil(HetznerDeployConfig.production_smoke_ip)
    end
  ensure
    ENV["PRODUCTION_DOMAIN_MODE"] = original
  end
end
