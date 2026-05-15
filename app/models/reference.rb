class Reference < RussRecord
  STATUSES = %w[draft published].freeze
  TAG_SPLIT_PATTERN = /[\n,]+/

  has_one :reference_image, dependent: :destroy

  accepts_nested_attributes_for :reference_image

  normalizes :title, :location, :production, with: ->(value) { value.to_s.strip }

  before_validation :normalize_tags

  validates :title, presence: true, length: { maximum: 180 }
  validates :starts_on, presence: true
  validates :location, presence: true, length: { maximum: 180 }
  validates :production, length: { maximum: 180 }, allow_blank: true
  validates :description, :description_en, length: { maximum: 500 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc, starts_on: :desc, id: :asc) }
  scope :published, -> { where(status: "published") }
  scope :with_image, -> { includes(:reference_image) }
  scope :tagged_with_any, lambda { |tags|
    normalized_tags = Array(tags).map { |tag| tag.to_s.strip.downcase }.reject(&:blank?).uniq

    if normalized_tags.empty?
      none
    else
      where(
        "EXISTS (SELECT 1 FROM unnest(tags) AS reference_tags(tag_name) WHERE lower(reference_tags.tag_name) IN (:tags))",
        tags: normalized_tags
      )
    end
  }
  scope :matching, lambda { |query|
    normalized_query = query.to_s.strip
    next all if normalized_query.blank?

    pattern = "%#{sanitize_sql_like(normalized_query)}%"
    where(
      "title ILIKE :query OR location ILIKE :query OR production ILIKE :query OR EXISTS (SELECT 1 FROM unnest(tags) AS tag WHERE tag ILIKE :query)",
      query: pattern
    )
  }

  def self.tags_from(records)
    records.flat_map { |record| record.tags.to_a }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq { |tag| tag.downcase }
      .sort_by(&:downcase)
  end

  def self.tag_slug(tag)
    tag.to_s.parameterize
  end

  def tag_list
    tags.to_a.join(", ")
  end

  def tag_list=(value)
    self.tags = normalized_tag_values(value)
  end

  def tag_slugs
    tags.to_a.map { |tag| self.class.tag_slug(tag) }.reject(&:blank?)
  end

  def published?
    status == "published"
  end

  def display_status
    published? ? "Veröffentlicht" : "Entwurf"
  end

  def year
    starts_on&.year
  end

  def localized_description(locale = I18n.locale)
    return description_en.presence || description if locale.to_s == "en"

    description
  end

  def build_reference_image_with_defaults
    reference_image || build_reference_image(alt_text: title, grid_variant: ReferenceImage::GRID_VARIANT_1X1)
  end

  private
    def normalize_tags
      self.tags = normalized_tag_values(tags)
    end

    def normalized_tag_values(value)
      Array(value)
        .flat_map { |item| item.to_s.split(TAG_SPLIT_PATTERN) }
        .map(&:strip)
        .reject(&:blank?)
        .uniq { |tag| tag.downcase }
    end
end
