class EventImage < SharedStuttgartRecord
  PURPOSE_SLIDER = "slider".freeze
  PURPOSE_DETAIL_HERO = "detail_hero".freeze
  WEB_MAX_DIMENSION = 1280
  WEB_QUALITY = 82
  PRESS_VARIANT_MAX_DIMENSIONS = {
    hero_mobile: 768,
    hero_desktop: WEB_MAX_DIMENSION,
    gallery_mobile: 384,
    gallery_desktop: 768
  }.freeze

  self.table_name = "event_images"

  belongs_to :event
  has_one_attached :file

  scope :ordered, -> { order(created_at: :asc, id: :asc) }
  scope :slider, -> { where(purpose: PURPOSE_SLIDER) }
  scope :detail_hero, -> { where(purpose: PURPOSE_DETAIL_HERO) }

  def slider?
    purpose == PURPOSE_SLIDER
  end

  def detail_hero?
    purpose == PURPOSE_DETAIL_HERO
  end

  def press_variant(size)
    file.variant(**variant_transformations(max_dimension: PRESS_VARIANT_MAX_DIMENSIONS.fetch(size.to_sym)))
  end

  private

  def variant_transformations(max_dimension:)
    transformations = {
      format: :webp,
      resize_to_limit: [ max_dimension, max_dimension ]
    }

    if ActiveStorage.variant_processor == :vips
      transformations[:saver] = {
        strip: true,
        quality: WEB_QUALITY
      }
    end

    transformations
  end
end
