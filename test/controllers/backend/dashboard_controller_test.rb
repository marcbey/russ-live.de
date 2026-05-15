require "test_helper"

class Backend::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    @admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")
  end

  test "requires authentication" do
    get backend_root_path

    assert_redirected_to new_session_url
  end

  test "renders for authorized Stuttgart user" do
    sign_in_as(@admin)
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Referenzen verwalten"
  end
end
