require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    @admin = create_stuttgart_user!(email_address: "admin@russ-live.de", role: "admin")
    @login_logs = StringIO.new
    @login_log_sink = ActiveSupport::Logger.new(@login_logs)
    Rails.logger.broadcast_to(@login_log_sink)
  end

  teardown { Rails.logger.stop_broadcasting_to(@login_log_sink) }

  test "new renders login with STUTTGARTLIVE password reset link" do
    get new_session_path

    assert_response :success
    assert_select "body.auth-body"
    assert_select "form[action='#{session_path}']"
    assert_select "a[href='https://www.stuttgart-live.de/passwords/new']", text: "Passwort vergessen"
  end

  test "stage password reset remains in the staging pair" do
    previous = Rails.configuration.x.deployment_environment
    Rails.configuration.x.deployment_environment = "staging"
    get new_session_path
    assert_response :success
    assert_select "a[href='https://staging.stuttgart-live.de/passwords/new']", text: "Passwort vergessen"
  ensure
    Rails.configuration.x.deployment_environment = previous
  end

  test "nested references login path redirects to canonical login" do
    get "/referenzen/login"

    assert_redirected_to new_session_path
  end

  test "login creates a local Russ session and redirects to backend" do
    assert_difference -> { Session.count }, 1 do
      assert_no_difference -> { LoginAttempt.count } do
        sign_in_as(@admin)
      end
    end

    assert_redirected_to backend_root_url
    assert cookies[:session_id].present?
    assert_equal @admin, Session.last.user
    assert_equal "successful", last_login_log.fetch("outcome")
  end

  test "login rejects invalid credentials and logs a failed attempt" do
    assert_no_difference -> { Session.count } do
      assert_no_difference -> { LoginAttempt.count } do
        post session_path, params: {
          email_address: @admin.email_address,
          password: "falsch"
        }
      end
    end

    assert_redirected_to new_session_url
    assert_equal({ "event" => "login_attempt", "outcome" => "failed" }, last_login_log)
  end

  test "login rejects Stuttgart users without Russ backend role" do
    blogger = create_stuttgart_user!(email_address: "blogger@russ-live.de", role: "blogger")

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

    assert_redirected_to root_url
    assert_not Session.exists?(session_id)
  end

  private

  def last_login_log
    line = @login_logs.string.lines.reverse.find { |entry| entry.start_with?('{"event":"login_attempt"') }
    assert line, "expected a login attempt in the application log"
    JSON.parse(line)
  end
end
