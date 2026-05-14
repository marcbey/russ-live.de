class SessionsController < ApplicationController
  STUTTGART_LIVE_PASSWORD_RESET_URL = "https://www.stuttgart-live.de/passwords/new".freeze

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Bitte später erneut versuchen." }

  def new
    @page_meta = {
      title: "Login | Russ Live",
      body_class: "auth-body"
    }
    @password_reset_url = STUTTGART_LIVE_PASSWORD_RESET_URL
  end

  def create
    authenticated_user = User.authenticate_by(email_address: normalized_email_address, password: params[:password].to_s)

    if authenticated_user&.russ_access?
      log_login_attempt(user: authenticated_user, outcome: "successful")
      start_new_session_for(authenticated_user)
      redirect_to after_authentication_url
    else
      log_login_attempt(user: candidate_user, outcome: "failed")
      redirect_to new_session_path, alert: "E-Mail oder Passwort ist ungültig."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    def normalized_email_address
      params[:email_address].to_s.strip.downcase
    end

    def candidate_user
      @candidate_user ||= User.find_by(email_address: normalized_email_address)
    end

    def log_login_attempt(user:, outcome:)
      LoginAttempt.create!(
        user: user,
        email_address: normalized_email_address.presence,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        outcome: outcome
      )
    end
end
