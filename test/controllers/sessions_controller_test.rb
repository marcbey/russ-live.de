require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    @admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")
  end

  test "new renders login with Stuttgart Live password reset link" do
    get new_session_path

    assert_response :success
    assert_select "body.auth-body"
    assert_select "form[action='#{session_path}']"
    assert_select "a[href='https://www.stuttgart-live.de/passwords/new']", text: "Passwort vergessen"
  end

  test "nested references login path redirects to canonical login" do
    get "/referenzen/login"

    assert_redirected_to new_session_path
  end

  test "login creates a local Russ session and redirects to backend" do
    assert_difference -> { Session.count }, 1 do
      assert_difference -> { LoginAttempt.where(outcome: "successful").count }, 1 do
        sign_in_as(@admin)
      end
    end

    assert_redirected_to backend_root_url
    assert cookies[:session_id].present?
    assert_equal @admin, Session.last.user
  end

  test "login rejects invalid credentials and stores a local failed attempt" do
    assert_no_difference -> { Session.count } do
      assert_difference -> { LoginAttempt.where(outcome: "failed").count }, 1 do
        post session_path, params: {
          email_address: @admin.email_address,
          password: "falsch"
        }
      end
    end

    assert_redirected_to new_session_url
  end

  test "login rejects Stuttgart users without Russ backend role" do
    blogger = create_stuttgart_user!(email_address: "blogger@example.com", role: "blogger")

    assert_no_difference -> { Session.count } do
      post session_path, params: {
        email_address: blogger.email_address,
        password: STRONG_PASSWORD
      }
    end

    assert_redirected_to new_session_url
  end

  test "logout deletes the current Russ session" do
    sign_in_as(@admin)
    session_id = Session.last.id

    delete session_path

    assert_redirected_to new_session_url
    assert_not Session.exists?(session_id)
  end
end
