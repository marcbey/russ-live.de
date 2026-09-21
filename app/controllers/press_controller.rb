require "zip"

class PressController < ApplicationController
  allow_unauthenticated_access

  PAGE_META = {
    body_class: "press-body"
  }.freeze

  before_action :set_page_context
  before_action :set_public_header_jobs, except: :download

  def index
    @press_artists = press_artists
    @press_artist_groups = PressArtist.grouped(@press_artists)
    @press_artist_group_columns = @press_artist_groups.to_a.in_groups(2, false).reject(&:empty?)
    @press_artist_count = @press_artists.size

    render "pages/presse"
  end

  def show
    @press_artist = find_press_artist!
    @page_meta = PAGE_META.merge(
      title: t("press.detail.meta.title", name: @press_artist.name),
      description: t("press.detail.meta.description", name: @press_artist.name)
    )

    render "pages/press_detail"
  end

  def download
    @press_artist = find_press_artist!
    raise ActionController::RoutingError, "Not Found" if @press_artist.gallery_images.empty?

    send_data press_kit_zip(@press_artist),
      filename: "#{@press_artist.slug}-pressekit.zip",
      type: "application/zip",
      disposition: "attachment"
  end

  def text_download
    @press_artist = find_press_artist!
    raise ActionController::RoutingError, "Not Found" if press_text_plain(@press_artist).blank?

    response.headers["Cache-Control"] = "no-store"
    send_data press_text_pdf(@press_artist),
      filename: "#{@press_artist.slug}-pressetext.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end

  private

  def find_press_artist!
    press_artists.find { |artist| artist.slug == params[:slug] }.tap do |artist|
      raise ActionController::RoutingError, "Not Found" if artist.blank?
    end
  end

  def set_page_context
    @page_key = :presse
    @page_meta = PAGE_META.merge(
      title: t("pages.presse.meta.title"),
      description: t("pages.presse.meta.description")
    )
  end

  def set_public_header_jobs
    @public_header_jobs = Job.published.ordered.select(:id, :title, :slug).to_a
  end

  def press_artists
    @press_artists ||= PressArtist.from_events(press_events.to_a)
  end

  def press_events
    return [] unless shared_events_table_available?

    Event
      .published_on_russ_live
      .includes(
        :venue_record,
        :event_offers,
        :rich_text_press_text,
        event_images: [ file_attachment: :blob ]
      )
  end

  def shared_events_table_available?
    ActiveRecord::Base.connection.data_source_exists?(Event.table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    raise if Rails.env.production?

    false
  end

  def press_kit_zip(artist)
    Zip::OutputStream.write_buffer do |zip|
      artist.gallery_images.each_with_index do |image, index|
        zip.put_next_entry(zip_entry_name(image, index))
        zip.write image.file.download
      end

      if press_text_plain(artist).present?
        zip.put_next_entry("#{artist.slug}-pressetext.pdf")
        zip.write press_text_pdf(artist)
      end
    end.string
  end

  def press_text_pdf(artist)
    PressTextPdf.new(
      title: artist.name,
      text: press_text_plain(artist),
      generated_label: t("press.detail.press_text.pdf_generated", date: Date.current.strftime("%d.%m.%Y")),
      document_label: t("press.detail.press_text.eyebrow"),
      logo_path: Rails.root.join("app/assets/images/russ_live/logos/russ-live-logo.png")
    ).render
  end

  def press_text_plain(artist)
    body = artist.press_body
    return "" if body.blank?
    return body.to_plain_text.strip if body.respond_to?(:to_plain_text)

    body.to_s.strip
  end

  def zip_entry_name(image, index)
    filename = image.file.filename.to_s
    extension = File.extname(filename)
    basename = File.basename(filename, extension).presence || "pressebild"
    safe_basename = basename.parameterize.presence || "pressebild"

    "#{index + 1}-#{safe_basename}#{extension}"
  end
end
