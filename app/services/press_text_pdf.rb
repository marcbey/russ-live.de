require "vips"

class PressTextPdf
  PAGE_WIDTH = 595
  PAGE_HEIGHT = 842
  PAGE_MARGIN = 56
  REGULAR_FONT = "F1".freeze
  BOLD_FONT = "F2".freeze
  LOGO_NAME = "Logo".freeze
  LOGO_WIDTH = 150
  LOGO_HEIGHT = 32
  TITLE_SIZE = 26
  LABEL_SIZE = 12
  META_SIZE = 11
  BODY_SIZE = 11
  BODY_LEADING = 17
  TITLE_LEADING = 31

  LogoImage = Data.define(:data, :width, :height)

  def initialize(title:, text:, generated_label:, document_label:, logo_path:)
    @title = title.to_s.strip.presence || document_label
    @text = text.to_s.strip
    @generated_label = generated_label.to_s.strip
    @document_label = document_label.to_s.strip
    @logo_path = logo_path
  end

  def render
    logo = logo_image
    streams = page_streams(logo.present?)

    build_document(base_objects(streams, logo))
  end

  private

  attr_reader :title, :text, :generated_label, :document_label, :logo_path

  def page_streams(logo_present)
    streams = []
    commands = []
    y = add_page_header(commands, logo_present:, first_page: true)

    paragraphs.each do |paragraph|
      wrapped_lines(paragraph).each do |line|
        if y < PAGE_MARGIN + BODY_LEADING
          streams << commands.join("\n")
          commands = []
          y = add_page_header(commands, logo_present:, first_page: false)
        end

        add_line(commands, line, PAGE_MARGIN, y, BODY_SIZE)
        y -= BODY_LEADING
      end

      y -= BODY_LEADING / 2
    end

    streams << commands.join("\n")
    streams
  end

  def add_page_header(commands, logo_present:, first_page:)
    y = PAGE_HEIGHT - PAGE_MARGIN
    if logo_present
      commands << "q #{LOGO_WIDTH} 0 0 #{LOGO_HEIGHT} #{PAGE_MARGIN} #{y - LOGO_HEIGHT} cm /#{LOGO_NAME} Do Q"
      y -= LOGO_HEIGHT + 28
    end

    return add_first_page_heading(commands, y) if first_page

    add_line(commands, "#{document_label} | #{title}", PAGE_MARGIN, y, META_SIZE, font: BOLD_FONT)
    y - (BODY_LEADING * 2)
  end

  def add_first_page_heading(commands, y)
    add_line(commands, document_label, PAGE_MARGIN, y, LABEL_SIZE, font: BOLD_FONT)
    y -= BODY_LEADING + 6
    add_line(commands, title, PAGE_MARGIN, y, TITLE_SIZE, font: BOLD_FONT)
    y -= TITLE_LEADING

    if generated_label.present?
      add_line(commands, generated_label, PAGE_MARGIN, y, META_SIZE)
      y -= BODY_LEADING * 2
    else
      y -= BODY_LEADING
    end

    y
  end

  def paragraphs
    text.split(/\n{2,}/).map { |paragraph| paragraph.gsub(/\s+/, " ").strip }.compact_blank
  end

  def wrapped_lines(paragraph)
    lines = []
    current_line = +""

    paragraph.split(/\s+/).each do |word|
      candidate = current_line.blank? ? word : "#{current_line} #{word}"
      if candidate.length > 82 && current_line.present?
        lines << current_line
        current_line = word
      else
        current_line = candidate
      end
    end

    lines << current_line if current_line.present?
    lines
  end

  def add_line(commands, line, x, y, size, font: REGULAR_FONT)
    commands << "BT /#{font} #{size} Tf 1 0 0 1 #{x} #{y} Tm #{pdf_text(line)} Tj ET"
  end

  def base_objects(streams, logo)
    fixed_count = logo.present? ? 6 : 5
    content_start = fixed_count + 1
    page_start = content_start + streams.size
    objects = fixed_objects(streams, page_start, logo)
    streams.each { |stream| objects << stream_object(stream) }
    streams.each_index { |index| objects << page_object(content_start + index, logo) }
    objects
  end

  def fixed_objects(streams, page_start, logo)
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids #{page_refs(page_start, streams.size)} /Count #{streams.size} >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>",
      "<< /Producer #{pdf_text("Russ Live")} >>"
    ]
    objects << logo_object(logo) if logo.present?
    objects
  end

  def page_object(content_ref, logo)
    x_object = logo.present? ? " /XObject << /#{LOGO_NAME} 6 0 R >>" : ""
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{PAGE_WIDTH} #{PAGE_HEIGHT}] " \
      "/Resources << /Font << /#{REGULAR_FONT} 3 0 R /#{BOLD_FONT} 4 0 R >>#{x_object} >> " \
      "/Contents #{content_ref} 0 R >>"
  end

  def stream_object(stream)
    "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
  end

  def logo_object(logo)
    header = "<< /Type /XObject /Subtype /Image /Width #{logo.width} /Height #{logo.height} " \
      "/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{logo.data.bytesize} >>\nstream\n"
    header.b + logo.data + "\nendstream".b
  end

  def logo_image
    image = Vips::Image.new_from_file(logo_path.to_s, access: :sequential)
    image = image.flatten(background: [ 255 ]) if image.has_alpha?
    image = image.colourspace(:srgb)

    LogoImage.new(data: image.jpegsave_buffer(Q: 90, strip: true), width: image.width, height: image.height)
  rescue Vips::Error, Errno::ENOENT => error
    Rails.logger.warn("Press text PDF logo unavailable: #{error.message}")
    nil
  end

  def build_document(objects)
    body = +"%PDF-1.4\n".b
    offsets = []
    objects.each_with_index do |object, index|
      offsets << body.bytesize
      body << "#{index + 1} 0 obj\n".b << object.b << "\nendobj\n".b
    end

    xref_offset = body.bytesize
    body << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n".b
    offsets.each { |offset| body << format("%010d 00000 n \n", offset).b }
    body << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R /Info 5 0 R >>\n".b
    body << "startxref\n#{xref_offset}\n%%EOF\n".b
    body
  end

  def page_refs(start, count)
    "[#{count.times.map { |index| "#{start + index} 0 R" }.join(" ")}]"
  end

  def pdf_text(value)
    bytes = value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").bytes
    escaped = bytes.map do |byte|
      case byte
      when 40, 41, 92 then "\\#{byte.chr}"
      when 0..31, 127..255 then format("\\%03o", byte)
      else byte.chr
      end
    end.join

    "(#{escaped})"
  end
end
