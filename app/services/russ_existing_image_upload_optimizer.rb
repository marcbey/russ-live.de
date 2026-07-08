class RussExistingImageUploadOptimizer
  Field = Struct.new(
    :model,
    :file_path,
    :content_type,
    :filename,
    :byte_size,
    keyword_init: true
  )

  FIELDS = [
    Field.new(
      model: ReferenceImage,
      file_path: :file_path,
      content_type: :content_type,
      filename: :filename,
      byte_size: :byte_size
    ),
    Field.new(
      model: ReferenceImage,
      file_path: :slider_file_path,
      content_type: :slider_content_type,
      filename: :slider_filename,
      byte_size: :slider_byte_size
    ),
    Field.new(
      model: JobImage,
      file_path: :file_path,
      content_type: :content_type,
      filename: :filename,
      byte_size: :byte_size
    ),
    Field.new(
      model: ContactImage,
      file_path: :file_path,
      content_type: :content_type,
      filename: :filename,
      byte_size: :byte_size
    )
  ].freeze

  def self.call
    new.call
  end

  def initialize
    @stats = Hash.new(0)
  end

  def call
    FIELDS.each { |field| optimize_field(field) }
    stats
  end

  private
    attr_reader :stats

    def optimize_field(field)
      field.model.where.not(field.file_path => nil).find_each do |record|
        optimize_record(record, field)
      rescue StandardError => e
        stats[:failed] += 1
        warn "#{field.model.name}##{record.id}: #{e.class} #{e.message}"
      end
    end

    def optimize_record(record, field)
      source_path = disk_path(record.public_send(field.file_path))
      if source_path.blank? || !source_path.file?
        stats[:missing] += 1
        return
      end

      content_type = image_content_type(record, field, source_path)
      filename = image_filename(record, field, source_path)
      target_relative_path = optimized_relative_path(record.public_send(field.file_path), content_type, filename)
      target_path = disk_path(target_relative_path)

      optimized_image = RussImageUploadOptimizer.call(
        source_path: source_path,
        target_path: target_path,
        original_filename: filename,
        content_type: content_type
      )

      record.update!(
        field.file_path => target_relative_path,
        field.content_type => optimized_image.content_type,
        field.filename => optimized_image.filename,
        field.byte_size => optimized_image.byte_size
      )

      FileUtils.rm_f(source_path) unless source_path == target_path
      stats[:optimized] += 1
    end

    def disk_path(relative_path)
      return if relative_path.blank?

      storage_root = Rails.root.join("storage")
      path = storage_root.join(relative_path).cleanpath
      return unless path.to_s.start_with?("#{storage_root}/")

      path
    end

    def image_content_type(record, field, source_path)
      record.public_send(field.content_type).presence ||
        Rack::Mime.mime_type(source_path.extname, "application/octet-stream")
    end

    def image_filename(record, field, source_path)
      record.public_send(field.filename).presence || source_path.basename.to_s
    end

    def optimized_relative_path(relative_path, content_type, filename)
      extension = RussImageUploadOptimizer.target_extension(
        content_type: content_type,
        original_filename: filename
      )

      File.join(
        File.dirname(relative_path),
        "#{File.basename(relative_path, '.*')}#{extension}"
      )
    end
end
