class User < SharedStuttgartRecord
  ROLES = %w[admin editor].freeze

  self.table_name = "users"

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(email_address) { email_address.to_s.strip.downcase }

  def admin?
    role == "admin"
  end

  def editor?
    role == "editor"
  end

  def russ_access?
    admin? || editor?
  end

  alias_method :backend_access?, :russ_access?
end
