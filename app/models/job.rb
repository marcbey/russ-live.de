class Job < RussRecord
  STATUSES = %w[draft published].freeze
  CATEGORY_SPLIT_PATTERN = /[\n,]+/
  LOCALIZED_TEXT_ATTRIBUTES = %i[title badge intro highlight_text meta_title meta_description].freeze

  belongs_to :contact, optional: true
  has_one :job_image, dependent: :destroy

  accepts_nested_attributes_for :job_image

  normalizes :slug, :title, :badge, :title_en, :badge_en, :employment, :location,
             :highlight_label, :highlight_title, :join_recruiting_url, :meta_title,
             :meta_title_en, with: ->(value) { value.to_s.strip }

  before_validation :set_slug, :normalize_categories, :normalize_list_values

  validates :slug, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 180 }
  validates :title, presence: true, length: { maximum: 180 }
  validates :badge, :title_en, :badge_en, :employment, :location, :highlight_label,
            :highlight_title, :meta_title, :meta_title_en, length: { maximum: 180 }, allow_blank: true
  validates :location, presence: true
  validates :intro, :intro_en, :highlight_text, :highlight_text_en, :meta_description,
            :meta_description_en, length: { maximum: 600 }, allow_blank: true
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

  def self.reorder_by_ids!(ids)
    normalized_ids = Array(ids).map(&:to_i).select(&:positive?).uniq
    records_by_id = where(id: normalized_ids).index_by(&:id)

    transaction do
      normalized_ids.each_with_index do |id, index|
        records_by_id[id]&.update!(position: index + 1)
      end
    end
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

  def responsibilities_en_text
    responsibilities_en.to_a.join("\n")
  end

  def responsibilities_en_text=(value)
    self.responsibilities_en = normalized_multiline_values(value)
  end

  def requirements_en_text
    requirements_en.to_a.join("\n")
  end

  def requirements_en_text=(value)
    self.requirements_en = normalized_multiline_values(value)
  end

  def optional_text
    highlight_text
  end

  def optional_text=(value)
    self.highlight_text = value
  end

  def optional_text_en
    highlight_text_en
  end

  def optional_text_en=(value)
    self.highlight_text_en = value
  end

  def localized_title(locale = I18n.locale)
    localized_text(:title, locale)
  end

  def localized_badge(locale = I18n.locale)
    localized_text(:badge, locale)
  end

  def localized_intro(locale = I18n.locale)
    localized_text(:intro, locale)
  end

  def localized_optional_text(locale = I18n.locale)
    localized_text(:highlight_text, locale)
  end

  def localized_responsibilities(locale = I18n.locale)
    localized_list(:responsibilities, locale)
  end

  def localized_requirements(locale = I18n.locale)
    localized_list(:requirements, locale)
  end

  def localized_meta_title(locale = I18n.locale)
    localized_text(:meta_title, locale)
  end

  def localized_meta_description(locale = I18n.locale)
    localized_text(:meta_description, locale)
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
    I18n.t("jobs.detail.aria_label", title: localized_title)
  end

  def application_email_subject
    I18n.t("jobs.detail.application_email_subject", title: localized_title)
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
      self.responsibilities_en = normalized_text_values(responsibilities_en)
      self.requirements_en = normalized_text_values(requirements_en)
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

    def localized_text(attribute_name, locale)
      translated_attribute = "#{attribute_name}_en"
      translated_value = public_send(translated_attribute) if locale.to_s == "en" && LOCALIZED_TEXT_ATTRIBUTES.include?(attribute_name)
      translated_value.presence || public_send(attribute_name)
    end

    def localized_list(attribute_name, locale)
      translated_values = public_send("#{attribute_name}_en") if locale.to_s == "en"
      translated_values.to_a.compact_blank.presence || public_send(attribute_name).to_a
    end

    def join_recruiting_url_is_http_url
      return if join_recruiting_url.blank?

      uri = URI.parse(join_recruiting_url)
      errors.add(:join_recruiting_url, "muss eine gültige http- oder https-URL sein") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:join_recruiting_url, "muss eine gültige http- oder https-URL sein")
    end
end
