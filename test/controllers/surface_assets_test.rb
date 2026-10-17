require "test_helper"

class SurfaceAssetsTest < ActionDispatch::IntegrationTest
  test "public pages load frontend assets" do
    get root_path

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='/assets/frontend-']", count: 1
    assert_select "script[src*='/assets/frontend-']", count: 1
    assert_select "link[href*='/assets/backend-'], script[src*='/assets/backend-']", count: 0
  end

  test "login loads backend assets and local fonts" do
    get new_session_path

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='/assets/backend-']", count: 1
    assert_select "script[src*='/assets/backend-']", count: 1
    assert_select "link[href*='/assets/frontend-'], script[src*='/assets/frontend-']", count: 0
    assert_includes response.body, "NeueRational-Light"
  end
end
