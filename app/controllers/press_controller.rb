require "zip"

class PressController < ApplicationController
  allow_unauthenticated_access

  PAGE_META = {
    title: "Presse | Russ Live",
    body_class: "press-body"
  }.freeze

  before_action :set_page_context

  def index
    @press_artists = press_artists
    @press_artist_groups = PressArtist.grouped(@press_artists)
    @press_artist_count = @press_artists.size

    render "pages/presse"
  end

  def show
    @press_artist = find_press_artist!
    @page_meta = PAGE_META.merge(title: "#{@press_artist.name} | Presse | Russ Live")

    render "pages/press_detail"
  end

  def download
    @press_artist = find_press_artist!
    raise ActionController::RoutingError, "Not Found" if @press_artist.gallery_images.empty?

    send_data press_images_zip(@press_artist),
      filename: "#{@press_artist.slug}-pressebilder.zip",
      type: "application/zip",
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
    @page_meta = PAGE_META
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

  def press_images_zip(artist)
    Zip::OutputStream.write_buffer do |zip|
      artist.gallery_images.each_with_index do |image, index|
        zip.put_next_entry(zip_entry_name(image, index))
        zip.write image.file.download
      end
    end.string
  end

  def zip_entry_name(image, index)
    filename = image.file.filename.to_s
    extension = File.extname(filename)
    basename = File.basename(filename, extension).presence || "pressebild"
    safe_basename = basename.parameterize.presence || "pressebild"

    "#{index + 1}-#{safe_basename}#{extension}"
  end
end
