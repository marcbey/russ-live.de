class TeamMember < RussRecord
  has_one :team_member_image, dependent: :destroy

  normalizes :name, :role, :role_en, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: 180 }
  validates :role, :role_en, length: { maximum: 180 }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc, name: :asc, id: :asc) }
  scope :with_image, -> { includes(:team_member_image) }
  scope :matching, lambda { |query|
    normalized_query = query.to_s.strip
    next all if normalized_query.blank?

    pattern = "%#{sanitize_sql_like(normalized_query)}%"
    where("name ILIKE :query OR role ILIKE :query OR role_en ILIKE :query", query: pattern)
  }

  def localized_role
    return role_en if I18n.locale == :en && role_en.present?

    role
  end

  def build_team_member_image_with_defaults
    team_member_image || build_team_member_image(alt_text: name)
  end
end
