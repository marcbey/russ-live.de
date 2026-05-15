class Job < RussRecord
  STATUSES = %w[draft published].freeze
  CATEGORY_SPLIT_PATTERN = /[\n,]+/

  belongs_to :contact, optional: true
  has_one :job_image, dependent: :destroy

  accepts_nested_attributes_for :job_image

  normalizes :slug, :title, :badge, :employment, :location, :highlight_label, :highlight_title,
             :join_recruiting_url, :meta_title, with: ->(value) { value.to_s.strip }

  before_validation :set_slug, :normalize_categories, :normalize_list_values

  validates :slug, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 180 }
  validates :title, presence: true, length: { maximum: 180 }
  validates :badge, :employment, :location, :highlight_label, :highlight_title, :meta_title,
            length: { maximum: 180 }, allow_blank: true
  validates :location, presence: true
  validates :intro, :highlight_text, :meta_description, length: { maximum: 600 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :join_recruiting_url, length: { maximum: 500 }, allow_blank: true
  validate :join_recruiting_url_is_http_url

  scope :ordered, -> { order(position: :asc, title: :asc, id: :asc) }
  scope :published, -> { where(status: "published") }
  scope :with_contact_and_image, -> { includes(:contact, :job_image) }
  scope :matching, lambda { |query|
    normalized_query = query.to_s.strip
    next all if normalized_query.blank?

    pattern = "%#{sanitize_sql_like(normalized_query)}%"
    left_joins(:contact).where(
      "jobs.title ILIKE :query OR jobs.location ILIKE :query OR contacts.name ILIKE :query OR EXISTS (SELECT 1 FROM unnest(jobs.categories) AS category WHERE category ILIKE :query)",
      query: pattern
    )
  }

  def self.categories_from(records)
    records.flat_map { |record| record.categories.to_a }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq { |category| category.downcase }
      .sort_by(&:downcase)
  end

  def self.category_slug(category)
    category.to_s.parameterize
  end

  def category_list
    categories.to_a.join(", ")
  end

  def category_list=(value)
    self.categories = normalized_category_values(value)
  end

  def category_slugs
    categories.to_a.map { |category| self.class.category_slug(category) }.reject(&:blank?)
  end

  def primary_category
    categories.first
  end

  def responsibilities_text
    responsibilities.to_a.join("\n")
  end

  def responsibilities_text=(value)
    self.responsibilities = normalized_multiline_values(value)
  end

  def requirements_text
    requirements.to_a.join("\n")
  end

  def requirements_text=(value)
    self.requirements = normalized_multiline_values(value)
  end

  def published?
    status == "published"
  end

  def display_status
    published? ? "Veröffentlicht" : "Entwurf"
  end

  def detail_id
    "job-description"
  end

  def detail_label
    "Jobdetails #{title}"
  end

  def application_email_subject
    "Bewerbung #{title}"
  end

  def build_job_image_with_defaults
    job_image || build_job_image(alt_text: title)
  end

  private
    def set_slug
      self.slug = title.to_s.parameterize if slug.blank? && title.present?
    end

    def normalize_categories
      self.categories = normalized_category_values(categories)
    end

    def normalize_list_values
      self.responsibilities = normalized_text_values(responsibilities)
      self.requirements = normalized_text_values(requirements)
    end

    def normalized_category_values(value)
      Array(value)
        .flat_map { |item| item.to_s.split(CATEGORY_SPLIT_PATTERN) }
        .map(&:strip)
        .reject(&:blank?)
        .uniq { |category| category.downcase }
    end

    def normalized_text_values(value)
      Array(value).map(&:to_s).map(&:strip).reject(&:blank?)
    end

    def normalized_multiline_values(value)
      value.to_s.lines.map(&:strip).reject(&:blank?)
    end

    def join_recruiting_url_is_http_url
      return if join_recruiting_url.blank?

      uri = URI.parse(join_recruiting_url)
      errors.add(:join_recruiting_url, "muss eine gültige http- oder https-URL sein") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:join_recruiting_url, "muss eine gültige http- oder https-URL sein")
    end
end
