module AuthenticationTestHelper
  STRONG_PASSWORD = "Sicher123Pass".freeze

  def clear_auth_records
    LoginAttempt.delete_all
    Session.delete_all
  end

  def clear_stuttgart_users
    User.delete_all
  end

  def create_stuttgart_user!(email_address: "admin@example.com", password: STRONG_PASSWORD, role: "admin", name: "Admin")
    id = User.insert_all!([
      {
        email_address: email_address,
        password_digest: BCrypt::Password.create(password),
        role: role,
        name: name,
        created_at: Time.current,
        updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first

    User.find(id)
  end

  def sign_in_as(user, password: STRONG_PASSWORD)
    post session_path, params: {
      email_address: user.email_address,
      password: password
    }
  end
end
