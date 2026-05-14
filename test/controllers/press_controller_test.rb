require "test_helper"
require "zip"

class PressControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    clear_stuttgart_live_records
  end

  test "index lists only artists from published russ live events" do
    visible_event = create_event!(
      artist_name: "Ärztin Live",
      normalized_artist_name: "aerztin live",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 6, 1, 20)
    )
    create_event!(
      artist_name: "Hidden Act",
      normalized_artist_name: "hidden act",
      publish_on_russ_live: false,
      start_at: Time.zone.local(2026, 6, 2, 20)
    )

    get presse_path

    assert_response :success
    assert_includes response.body, "Ärztin Live"
    assert_includes response.body, press_artist_path("arztin-live")
    assert_includes response.body, "1 Presseeintrag"
    assert_select ".press-search[data-action=?]", "submit->press-search#submit reset->press-search#reset"
    assert_select "#press-search-input[data-action=?]", "input->press-search#render search->press-search#render"
    assert_not_includes response.body, "Hidden Act"
    assert_not_includes response.body, visible_event.title
  end

  test "index deduplicates artists by normalized artist name" do
    create_event!(
      artist_name: "Same Artist",
      normalized_artist_name: "same artist",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 6, 1, 20)
    )
    create_event!(
      artist_name: "Same Artist",
      normalized_artist_name: "same artist",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 7, 1, 20)
    )

    get presse_path

    assert_response :success
    assert_select ".press-artist-card", 1
    assert_includes response.body, "1 Presseeintrag"
  end

  test "show renders primary event, fallback press text, venue and further events" do
    venue_id = create_venue!(name: "Liederhalle Stuttgart")
    first_event = create_event!(
      artist_name: "Future Artist",
      normalized_artist_name: "future artist",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 8, 1, 20),
      event_info: "Fallback Pressetext",
      venue_id:
    )
    create_event_offer!(event_id: first_event.id, ticket_url: "https://tickets.example/%{event_id}", source_event_id: "abc")
    create_event!(
      artist_name: "Future Artist",
      normalized_artist_name: "future artist",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 9, 1, 20),
      venue_id:
    )

    get press_artist_path("future-artist")

    assert_response :success
    assert_includes response.body, "Future Artist"
    assert_includes response.body, "Fallback Pressetext"
    assert_includes response.body, "Liederhalle Stuttgart"
    assert_includes response.body, "Weitere Termine"
    assert_includes response.body, "https://tickets.example/abc"
  end

  test "show prefers rich press text over event info" do
    event = create_event!(
      artist_name: "Press Rich",
      normalized_artist_name: "press rich",
      publish_on_russ_live: true,
      event_info: "Fallback darf nicht erscheinen",
      start_at: Time.zone.local(2026, 8, 1, 20)
    )
    create_press_text!(event, "<div>Eigener Pressetext</div>")

    get press_artist_path("press-rich")

    assert_response :success
    assert_includes response.body, "Eigener Pressetext"
    assert_not_includes response.body, "Fallback darf nicht erscheinen"
  end

  test "show renders attached press images in gallery" do
    event = create_event!(
      artist_name: "Image Artist",
      normalized_artist_name: "image artist",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 8, 1, 20)
    )
    create_event_image!(event:, purpose: EventImage::PURPOSE_DETAIL_HERO, alt_text: "Eventbild", filename: "event-image.jpg")
    create_event_image!(event:, purpose: EventImage::PURPOSE_SLIDER, alt_text: "Freigegebenes Pressefoto", filename: "press-image.jpg")

    get press_artist_path("image-artist")

    assert_response :success
    assert_includes response.body, "Bildergalerie"
    assert_includes response.body, "Freigegebenes Pressefoto"
    assert_equal 2, response.body.scan("Pressemappe downloaden").size
    assert_equal 2, response.body.scan('data-turbo="false"').size
    assert_includes response.body, press_artist_download_path("image-artist")
    assert_includes response.body, "/rails/active_storage/representations/"
    assert_includes response.body, "Bild downloaden"
    assert_includes response.body, "disposition=attachment"
    assert_includes response.body, "data-lightbox-download="
  end

  test "download sends a zip with original press images" do
    event = create_event!(
      artist_name: "Zip Artist",
      normalized_artist_name: "zip artist",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 8, 1, 20)
    )
    create_event_image!(event:, purpose: EventImage::PURPOSE_DETAIL_HERO, alt_text: "ZIP Eventbild", filename: "event-image.jpg", content: "event image")
    create_event_image!(event:, purpose: EventImage::PURPOSE_SLIDER, alt_text: "ZIP Pressefoto", filename: "press-image.jpg", content: "press image")

    get press_artist_download_path("zip-artist")

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment; filename="zip-artist-pressebilder.zip"/, response.headers["Content-Disposition"])

    entries = []
    Zip::File.open_buffer(StringIO.new(response.body)) do |zip|
      entries = zip.map { |entry| [ entry.name, entry.get_input_stream.read ] }
    end
    assert_equal [ [ "1-press-image.jpg", "press image" ] ], entries
  end

  test "download returns not found when artist only has an event image" do
    event = create_event!(
      artist_name: "Only Event Image",
      normalized_artist_name: "only event image",
      publish_on_russ_live: true,
      start_at: Time.zone.local(2026, 8, 1, 20)
    )
    create_event_image!(event:, purpose: EventImage::PURPOSE_DETAIL_HERO, alt_text: "Nur Eventbild")

    get press_artist_download_path("only-event-image")

    assert_response :not_found
  end

  test "show returns not found for unknown artist slug" do
    get press_artist_path("unbekannt")

    assert_response :not_found
  end

  test "legacy press detail redirects to overview" do
    get "/presse/beispiel"

    assert_redirected_to "/presse"

    get "/presse-detail.html"

    assert_redirected_to "/presse"
  end

  private

  def clear_stuttgart_live_records
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
    ActionText::RichText.delete_all
    EventOffer.delete_all
    EventImage.delete_all
    Event.delete_all
    Venue.delete_all
  end

  def create_venue!(name:)
    Venue.insert_all!([
      {
        name:,
        created_at: Time.current,
        updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first
  end

  def create_event!(attributes)
    venue_id = attributes.delete(:venue_id) || create_venue!(name: "Im Wizemann")
    Event.insert_all!([
      {
        artist_name: attributes.fetch(:artist_name),
        normalized_artist_name: attributes.fetch(:normalized_artist_name),
        title: attributes.fetch(:title, "#{attributes.fetch(:artist_name)} Tour"),
        slug: attributes.fetch(:slug, "#{attributes.fetch(:artist_name).parameterize}-#{SecureRandom.hex(4)}"),
        status: attributes.fetch(:status, "published"),
        published_at: attributes.fetch(:published_at, 1.day.ago),
        start_at: attributes.fetch(:start_at),
        event_info: attributes[:event_info],
        publish_on_russ_live: attributes.fetch(:publish_on_russ_live),
        venue_id:,
        created_at: Time.current,
        updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first.then { |id| Event.find(id) }
  end

  def create_event_offer!(event_id:, ticket_url:, source_event_id:)
    EventOffer.insert_all!([
      {
        event_id:,
        metadata: {},
        priority_rank: 1,
        sold_out: false,
        source: "manual",
        source_event_id:,
        ticket_url:,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end

  def create_event_image!(event:, purpose:, alt_text:, filename: "press-image.jpg", content: "press image")
    image = EventImage.insert_all!([
      {
        event_id: event.id,
        purpose:,
        alt_text:,
        created_at: Time.current,
        updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first.then { |id| EventImage.find(id) }

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename:,
      content_type: "image/jpeg",
      service_name: "test"
    )
    ActiveStorage::Attachment.insert_all!([
      {
        name: "file",
        record_type: "EventImage",
        record_id: image.id,
        blob_id: blob.id,
        created_at: Time.current
      }
    ])
    image
  end

  def create_press_text!(event, body)
    ActionText::RichText.insert_all!([
      {
        record_type: "Event",
        record_id: event.id,
        name: "press_text",
        body:,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end
end
