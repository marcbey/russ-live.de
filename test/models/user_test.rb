require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    StuttgartLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
  end

  test "authenticates against Stuttgart Live users" do
    user = create_stuttgart_user!(email_address: "ADMIN@russ-live.de", password: STRONG_PASSWORD)

    authenticated = User.authenticate_by(email_address: "admin@russ-live.de", password: STRONG_PASSWORD)

    assert_equal user, authenticated
  end

  test "allows only admin and editor roles into Russ backend" do
    admin = create_stuttgart_user!(email_address: "admin@russ-live.de", role: "admin")
    editor = create_stuttgart_user!(email_address: "editor@russ-live.de", role: "editor")
    blogger = create_stuttgart_user!(email_address: "blogger@russ-live.de", role: "blogger")

    assert_predicate admin, :backend_access?
    assert_predicate editor, :backend_access?
    assert_not blogger.backend_access?
  end
end
