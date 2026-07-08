require "image_processing/vips"
require "securerandom"

class RussImageUploadOptimizer
  MAX_DIMENSION = 1_920
  WEB_QUALITY = 82
  WEBP_CONTENT_TYPE = "image/webp".freeze
  WEBP_EXTENSION = ".webp".freeze
  OPTIMIZABLE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  Result = Struct.new(:content_type, :filename, :byte_size, keyword_init: true)

  def self.call(source_path:, target_path:, original_filename:, content_type:)
    new(
      source_path: source_path,
      target_path: target_path,
      original_filename: original_filename,
      content_type: content_type
    ).call
  end

  def self.target_extension(content_type:, original_filename:)
    return WEBP_EXTENSION if optimizable_content_type?(content_type)

    File.extname(original_filename.to_s).presence ||
      Rack::Mime::MIME_TYPES.invert[content_type].to_s.presence ||
      ".bin"
  end

  def self.optimized_filename(original_filename:, content_type:)
    return original_filename.to_s if !optimizable_content_type?(content_type)

    basename = File.basename(original_filename.to_s, ".*").presence || "image"
    "#{basename}#{WEBP_EXTENSION}"
  end

  def self.optimizable_content_type?(content_type)
    OPTIMIZABLE_CONTENT_TYPES.include?(content_type.to_s)
  end

  def initialize(source_path:, target_path:, original_filename:, content_type:)
    @source_path = Pathname.new(source_path.to_s)
    @target_path = Pathname.new(target_path.to_s)
    @original_filename = original_filename.to_s
    @content_type = content_type.to_s
  end

  def call
    FileUtils.mkdir_p(target_path.dirname)

    if optimizable?
      process_web_image!
    else
      copy_original!
    end

    Result.new(
      content_type: result_content_type,
      filename: result_filename,
      byte_size: File.size(target_path)
    )
  end

  private
    attr_reader :source_path, :target_path, :original_filename, :content_type

    def optimizable?
      self.class.optimizable_content_type?(content_type)
    end

    def process_web_image!
      ImageProcessing::Vips
        .source(source_path.to_s)
        .resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
        .convert("webp")
        .saver(strip: true, Q: WEB_QUALITY)
        .call(destination: processing_target_path.to_s)

      FileUtils.mv(processing_target_path, target_path) if same_file_target?
    ensure
      FileUtils.rm_f(processing_target_path) if same_file_target? && processing_target_path.file?
    end

    def copy_original!
      FileUtils.cp(source_path, target_path) unless same_file_target?
    end

    def result_content_type
      optimizable? ? WEBP_CONTENT_TYPE : content_type
    end

    def result_filename
      self.class.optimized_filename(original_filename: original_filename, content_type: content_type)
    end

    def processing_target_path
      return target_path unless same_file_target?

      @processing_target_path ||= target_path.dirname.join(
        ".#{target_path.basename(target_path.extname)}-#{SecureRandom.hex(8)}#{target_path.extname}"
      )
    end

    def same_file_target?
      source_path.expand_path == target_path.expand_path
    end
end
