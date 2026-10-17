require "test_helper"
require "support/deploy_config_helper"

class ProductionDomainModeTest < ActiveSupport::TestCase
  include DeployConfigHelper

  test "domain preparation and cutover change only documented runtime values" do
    %w[prepared live_preissued live].each do |mode|
      config = render_deploy_config(destination: "hetzner", env: { "PRODUCTION_DOMAIN_MODE" => mode })
      clear = config.fetch("env").fetch("clear")
      assert_equal "russ-live.de", clear.fetch("APP_HOST")
      assert_equal "russ-live.de,www.russ-live.de", clear.fetch("APP_ALLOWED_HOSTS")
      assert_equal mode != "prepared", clear.fetch("CANONICAL_REDIRECT_ENABLED").to_s == "true"
      assert_equal mode == "prepared", clear.fetch("STAGING_NOINDEX").to_s == "true"
      assert_equal %w[russ-live.de www.russ-live.de], config.fetch("proxy").fetch("hosts")
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
end
