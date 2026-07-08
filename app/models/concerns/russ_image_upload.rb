module RussImageUpload
  extend ActiveSupport::Concern

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_UPLOAD_SIZE = 50.megabytes

  included do
    normalizes :alt_text, :sub_text, :filename, :content_type, with: ->(value) { value.to_s.strip }

    validates :alt_text, length: { maximum: 180 }, allow_blank: true
    validates :sub_text, length: { maximum: 250 }, allow_blank: true
    validates :filename, length: { maximum: 250 }, allow_blank: true
  end

  def uploaded?
    file_path.present?
  end

  def image?
    uploaded? || asset_path.present?
  end

  def display_alt_text
    alt_text.presence || image_owner_name
  end

  def write_uploaded_file!(upload)
    validate_upload!(upload)
    purge_file!

    extension = RussImageUploadOptimizer.target_extension(
      content_type: upload.content_type,
      original_filename: upload.original_filename
    )
    relative_path = File.join(storage_directory, id.to_s, "original#{extension}")
    target = Rails.root.join("storage", relative_path)
    optimized_upload = RussImageUploadOptimizer.call(
      source_path: upload.tempfile.path,
      target_path: target,
      original_filename: upload.original_filename,
      content_type: upload.content_type
    )

    update!(
      asset_path: nil,
      file_path: relative_path,
      filename: optimized_upload.filename,
      content_type: optimized_upload.content_type,
      byte_size: optimized_upload.byte_size
    )
  end

  def purge_file!
    return if file_path.blank?

    FileUtils.rm_f(Rails.root.join("storage", file_path))
  end

  def file_disk_path
    return if file_path.blank?

    Rails.root.join("storage", file_path)
  end

  private
    def validate_upload!(upload)
      raise ActiveRecord::RecordInvalid, self if upload.blank?

      unless IMAGE_CONTENT_TYPES.include?(upload.content_type)
        errors.add(:base, "Das Bild muss ein JPEG-, PNG-, WebP- oder GIF-Bild sein.")
      end

      errors.add(:base, "Das Bild darf maximal 50 MB groß sein.") if upload.size.to_i > MAX_UPLOAD_SIZE

      raise ActiveRecord::RecordInvalid, self if errors.any?
    end
end
