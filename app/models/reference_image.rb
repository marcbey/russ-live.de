class ReferenceImage < RussRecord
  DEFAULT_VARIANT = :default
  SLIDER_VARIANT = :slider
  GRID_VARIANT_1X1 = "1x1".freeze
  GRID_VARIANT_2X1 = "2x1".freeze
  GRID_VARIANT_1X2 = "1x2".freeze
  GRID_VARIANT_2X2 = "2x2".freeze
  GRID_VARIANTS = [
    GRID_VARIANT_1X1,
    GRID_VARIANT_2X1,
    GRID_VARIANT_1X2,
    GRID_VARIANT_2X2
  ].freeze
  DEFAULT_CARD_FOCUS_X = 50.0
  DEFAULT_CARD_FOCUS_Y = 50.0
  DEFAULT_CARD_ZOOM = 100.0
  MAX_UPLOAD_SIZE = 50.megabytes
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze

  belongs_to :reference

  normalizes :alt_text, :sub_text, :filename, :content_type,
             :slider_alt_text, :slider_sub_text, :slider_badge_text,
             :slider_filename, :slider_content_type,
             with: ->(value) { value.to_s.strip }

  validates :grid_variant, inclusion: { in: GRID_VARIANTS }
  validates :card_focus_x, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :card_focus_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :card_zoom, numericality: { greater_than_or_equal_to: 100, less_than_or_equal_to: 300 }
  validates :alt_text, length: { maximum: 180 }, allow_blank: true
  validates :sub_text, length: { maximum: 250 }, allow_blank: true
  validates :filename, length: { maximum: 250 }, allow_blank: true
  validates :slider_alt_text, length: { maximum: 180 }, allow_blank: true
  validates :slider_sub_text, length: { maximum: 250 }, allow_blank: true
  validates :slider_badge_text, length: { maximum: 80 }, allow_blank: true
  validates :slider_filename, length: { maximum: 250 }, allow_blank: true
  before_validation :normalize_image_values

  def uploaded?
    uploaded_for?(DEFAULT_VARIANT)
  end

  def image?
    image_for?(DEFAULT_VARIANT)
  end

  def slider_uploaded?
    uploaded_for?(SLIDER_VARIANT)
  end

  def slider_image?
    image_for?(SLIDER_VARIANT)
  end

  def display_alt_text
    alt_text.presence || reference.title
  end

  def display_slider_alt_text
    slider_alt_text.presence || display_alt_text
  end

  def card_focus_x_value
    card_focus_x.to_f
  end

  def card_focus_y_value
    card_focus_y.to_f
  end

  def card_zoom_value
    card_zoom.to_f.positive? ? card_zoom.to_f : DEFAULT_CARD_ZOOM
  end

  def write_uploaded_file!(upload, variant: DEFAULT_VARIANT)
    validate_upload!(upload)
    purge_file!(variant: variant)

    extension = RussImageUploadOptimizer.target_extension(
      content_type: upload.content_type,
      original_filename: upload.original_filename
    )
    relative_path = File.join("reference_images", id.to_s, "#{variant_basename(variant)}#{extension}")
    target = Rails.root.join("storage", relative_path)
    optimized_upload = RussImageUploadOptimizer.call(
      source_path: upload.tempfile.path,
      target_path: target,
      original_filename: upload.original_filename,
      content_type: upload.content_type
    )

    update!(uploaded_attributes(relative_path, optimized_upload, variant: variant))
  end

  def purge_file!(variant: DEFAULT_VARIANT)
    path_value = file_path_for(variant)
    return if path_value.blank?

    path = Rails.root.join("storage", path_value)
    FileUtils.rm_f(path)
  end

  def file_disk_path(variant: DEFAULT_VARIANT)
    path_value = file_path_for(variant)
    return if path_value.blank?

    Rails.root.join("storage", path_value)
  end

  private
    def uploaded_for?(variant)
      file_path_for(variant).present?
    end

    def image_for?(variant)
      uploaded_for?(variant) || asset_path_for(variant).present?
    end

    def file_path_for(variant)
      variant == SLIDER_VARIANT ? slider_file_path : file_path
    end

    def asset_path_for(variant)
      variant == SLIDER_VARIANT ? slider_asset_path : asset_path
    end

    def variant_basename(variant)
      variant == SLIDER_VARIANT ? "slider" : "original"
    end

    def uploaded_attributes(relative_path, upload, variant:)
      if variant == SLIDER_VARIANT
        {
          slider_asset_path: nil,
          slider_file_path: relative_path,
          slider_filename: upload.filename,
          slider_content_type: upload.content_type,
          slider_byte_size: upload.byte_size
        }
      else
        {
          asset_path: nil,
          file_path: relative_path,
          filename: upload.filename,
          content_type: upload.content_type,
          byte_size: upload.byte_size
        }
      end
    end

    def normalize_image_values
      self.grid_variant = grid_variant.to_s.strip.presence || GRID_VARIANT_1X1
      self.card_focus_x = normalize_percentage(card_focus_x, fallback: DEFAULT_CARD_FOCUS_X)
      self.card_focus_y = normalize_percentage(card_focus_y, fallback: DEFAULT_CARD_FOCUS_Y)
      self.card_zoom = normalize_percentage(card_zoom, fallback: DEFAULT_CARD_ZOOM)
    end

    def normalize_percentage(value, fallback:)
      return fallback if value.blank?

      value.to_f.round(2)
    end

    def validate_upload!(upload)
      raise ActiveRecord::RecordInvalid, self if upload.blank?

      unless IMAGE_CONTENT_TYPES.include?(upload.content_type)
        errors.add(:base, "Das Referenzbild muss ein JPEG-, PNG-, WebP- oder GIF-Bild sein.")
      end

      if upload.size.to_i > MAX_UPLOAD_SIZE
        errors.add(:base, "Das Referenzbild darf maximal 50 MB groß sein.")
      end

      raise ActiveRecord::RecordInvalid, self if errors.any?
    end
end
