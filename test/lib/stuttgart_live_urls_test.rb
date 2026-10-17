require "test_helper"

class StuttgartLiveUrlsTest < ActiveSupport::TestCase
  test "paired Stuttgart links use the stage host and preserve production behavior" do
    assert_equal "https://staging.stuttgart-live.de", StuttgartLiveUrls.base_url(environment: "staging")
    assert_equal "https://www.stuttgart-live.de", StuttgartLiveUrls.base_url(environment: "production")
    assert_raises(DeploymentEnvironment::ConfigurationError) { StuttgartLiveUrls.base_url(environment: nil) }
  end
end
