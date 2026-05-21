require "test_helper"

class NginxConfigTest < ActiveSupport::TestCase
  HEADER_PLACEHOLDER = "$" + "{STAGING_NOINDEX_HEADER}"

  test "supports optional staging noindex header" do
    config = Rails.root.join("config/nginx.conf.template").read

    assert_includes config, HEADER_PLACEHOLDER
    assert_operator config.scan(HEADER_PLACEHOLDER).size, :>=, 2
  end
end
