class Reference < RussRecord
  STATUSES = %w[draft published].freeze

  has_one :reference_image, dependent: :destroy

  accepts_nested_attributes_for :reference_image

  normalizes :title, :location, :production, with: ->(value) { value.to_s.strip }

  validates :title, presence: true, length: { maximum: 180 }
  validates :starts_on, presence: true
  validates :location, presence: true, length: { maximum: 180 }
  validates :production, length: { maximum: 180 }, allow_blank: true
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc, starts_on: :desc, id: :asc) }
  scope :published, -> { where(status: "published") }
  scope :with_image, -> { includes(:reference_image) }
  scope :matching, lambda { |query|
    normalized_query = query.to_s.strip
    next all if normalized_query.blank?

    pattern = "%#{sanitize_sql_like(normalized_query)}%"
    where("title ILIKE :query OR location ILIKE :query OR production ILIKE :query", query: pattern)
  }

  def published?
    status == "published"
  end

  def display_status
    published? ? "Veröffentlicht" : "Entwurf"
  end

  def year
    starts_on&.year
  end

  def build_reference_image_with_defaults
    reference_image || build_reference_image(alt_text: title, grid_variant: ReferenceImage::GRID_VARIANT_1X1)
  end
end
