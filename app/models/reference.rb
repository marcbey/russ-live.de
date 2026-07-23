class Reference < RussRecord
  DATE_INPUT_FORMAT = "%d.%m.%Y".freeze
  MONTH_NAMES = {
    "januar" => 1,
    "jan" => 1,
    "februar" => 2,
    "feb" => 2,
    "maerz" => 3,
    "marz" => 3,
    "maer" => 3,
    "mar" => 3,
    "april" => 4,
    "apr" => 4,
    "mai" => 5,
    "juni" => 6,
    "jun" => 6,
    "juli" => 7,
    "jul" => 7,
    "august" => 8,
    "aug" => 8,
    "september" => 9,
    "sep" => 9,
    "sept" => 9,
    "oktober" => 10,
    "okt" => 10,
    "november" => 11,
    "nov" => 11,
    "dezember" => 12,
    "dez" => 12
  }.freeze
  MONTH_NAME_PATTERN = MONTH_NAMES.keys.sort_by { |month_name| -month_name.length }.join("|")
  STATUSES = %w[draft published].freeze
  TAG_SPLIT_PATTERN = /[\n,]+/
  attr_writer :starts_on_input

  has_one :reference_image, dependent: :destroy

  accepts_nested_attributes_for :reference_image

  normalizes :title, :location, :production, :display_date, with: ->(value) { value.to_s.strip }

  before_validation :assign_starts_on_from_input
  before_validation :assign_starts_on_from_display_date
  before_validation :normalize_position
  before_validation :normalize_tags

  validates :title, presence: true, length: { maximum: 180 }
  validates :starts_on, presence: true
  validate :validate_starts_on_input_format
  validates :location, presence: true, length: { maximum: 180 }
  validates :production, length: { maximum: 180 }, allow_blank: true
  validates :display_date, length: { maximum: 120 }, allow_blank: true
  validates :description, :description_en, length: { maximum: 500 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(starts_on: :desc, id: :desc) }
  scope :published, -> { where(status: "published") }
  scope :featured, -> { where(featured: true) }
  scope :regular, -> { where(featured: false) }
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
      .group_by(&:downcase)
      .values
      .map { |variants| variants.max_by { |tag| tag.count("A-Z") } }
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

  def starts_on_input
    @starts_on_input.presence || starts_on&.strftime(DATE_INPUT_FORMAT)
  end

  def display_date_text
    display_date.presence || starts_on&.strftime(DATE_INPUT_FORMAT)
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

  def featured_image?
    reference_image&.image? || reference_image&.slider_image?
  end

  def build_reference_image_with_defaults
    reference_image || build_reference_image(alt_text: title, grid_variant: ReferenceImage::GRID_VARIANT_1X1)
  end

  private
    def normalize_position
      self.position = position.to_i if position.present?
      self.position = 1 if position.to_i <= 0
    end

    def assign_starts_on_from_input
      return unless defined?(@starts_on_input)

      self.starts_on = parse_starts_on_input(@starts_on_input)
    end

    def assign_starts_on_from_display_date
      return if defined?(@starts_on_input)

      parsed_date = parse_display_date(display_date)
      self.starts_on = parsed_date if parsed_date.present?
    end

    def normalize_tags
      self.tags = normalized_tag_values(tags)
    end

    def validate_starts_on_input_format
      return unless defined?(@starts_on_input)
      return if @starts_on_input.blank? || parse_starts_on_input(@starts_on_input).present?

      errors.add(:starts_on_input, "bitte im Format TT.MM.JJJJ eingeben")
    end

    def parse_starts_on_input(value)
      input = value.to_s.strip
      return if input.blank?

      Date.strptime(input, DATE_INPUT_FORMAT)
    rescue ArgumentError
      begin
        Date.iso8601(input)
      rescue ArgumentError
        nil
      end
    end

    def parse_display_date(value)
      input = value.to_s.strip
      return if input.blank?

      parse_starts_on_input(input) || parse_month_name_date(input)
    end

    def parse_month_name_date(value)
      normalized_input = I18n.transliterate(value.to_s).downcase
      matches = normalized_input.scan(/\b(#{MONTH_NAME_PATTERN})\b\.?\s+(\d{4})/)
      month_name, year = matches.last
      return if month_name.blank?

      Date.new(year.to_i, MONTH_NAMES.fetch(month_name), 1)
    end

    def normalized_tag_values(value)
      Array(value)
        .flat_map { |item| item.to_s.split(TAG_SPLIT_PATTERN) }
        .map(&:strip)
        .reject(&:blank?)
        .uniq { |tag| tag.downcase }
    end
end
