class Contact < RussRecord
  has_many :jobs, dependent: :restrict_with_error
  has_one :contact_image, dependent: :destroy

  accepts_nested_attributes_for :contact_image

  normalizes :name, :role, :phone_number, with: ->(value) { value.to_s.strip }
  normalizes :email, with: ->(value) { value.to_s.strip.downcase }

  validates :name, presence: true, length: { maximum: 180 }
  validates :role, length: { maximum: 180 }, allow_blank: true
  validates :phone_number, presence: true, length: { maximum: 80 }
  validates :email, presence: true, length: { maximum: 180 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc, name: :asc, id: :asc) }
  scope :with_image, -> { includes(:contact_image) }
  scope :matching, lambda { |query|
    normalized_query = query.to_s.strip
    next all if normalized_query.blank?

    pattern = "%#{sanitize_sql_like(normalized_query)}%"
    where("name ILIKE :query OR role ILIKE :query OR phone_number ILIKE :query OR email ILIKE :query", query: pattern)
  }

  def tel_href
    normalized = phone_number.to_s.gsub(/[^\d+]/, "")
    normalized = "+#{normalized.delete_prefix('00')}" if normalized.start_with?("00")
    normalized.start_with?("+") ? "+#{normalized.delete('+')}" : normalized
  end

  def build_contact_image_with_defaults
    contact_image || build_contact_image(alt_text: name)
  end
end
