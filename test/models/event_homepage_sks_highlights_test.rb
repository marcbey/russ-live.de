require "test_helper"

class EventHomepageSksHighlightsTest < ActiveSupport::TestCase
  setup do
    StuttgartLiveSchema.ensure!
    clear_stuttgart_live_records
    AppSetting.insert_all!([
      {
        key: AppSetting::SKS_PROMOTER_IDS_KEY,
        value: [ "10135", "Russ Klassik" ],
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end

  test "homepage sks highlights use promoter ids and names but not manual highlights" do
    sks_by_id = create_event!(artist_name: "SKS ID", promoter_id: "10135", start_at: 2.days.from_now)
    sks_by_name = create_event!(artist_name: "SKS Name", promoter_name: "Russ Klassik", start_at: 3.days.from_now)
    create_event!(artist_name: "Manual Highlight", promoter_id: "99999", highlighted: true, start_at: 4.days.from_now)

    assert_equal [ sks_by_id, sks_by_name ], Event.homepage_sks_highlights.to_a
  end

  test "home slider image prefers editorial event image over import image" do
    event = create_event!(promoter_id: "10135")
    event_image_id = EventImage.insert_all!([
      {
        event_id: event.id,
        purpose: EventImage::PURPOSE_DETAIL_HERO,
        alt_text: "Editorial",
        created_at: Time.current,
        updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first
    attach_test_image!(EventImage.find(event_image_id))
    create_import_event_image!(event: event, image_url: "https://img.example.test/import.jpg")

    assert_equal EventImage.find(event_image_id), event.reload.home_slider_image
  end

  test "home slider image falls back to import image when editorial image has no file" do
    event = create_event!(promoter_id: "10135")
    EventImage.insert_all!([
      {
        event_id: event.id,
        purpose: EventImage::PURPOSE_DETAIL_HERO,
        alt_text: "Editorial without file",
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    create_import_event_image!(event: event, image_url: "https://img.example.test/import.jpg")

    assert_instance_of ImportEventImage, event.reload.home_slider_image
  end

  test "public ticket status labels canceled and sold out offers" do
    canceled_event = create_event!(promoter_id: "10135")
    create_event_offer!(event: canceled_event, metadata: { availability_status: "canceled" })
    sold_out_event = create_event!(promoter_id: "10135")
    create_event_offer!(event: sold_out_event, sold_out: true)

    assert_equal "Abgesagt", canceled_event.reload.public_ticket_status_label
    assert_equal "Ausverkauft", sold_out_event.reload.public_ticket_status_label
    assert_nil canceled_event.public_ticket_offer
  end

  private

  def clear_stuttgart_live_records
    EventOffer.delete_all
    EventImage.delete_all
    ImportEventImage.delete_all
    Event.delete_all
    Venue.delete_all
    AppSetting.delete_all
  end

  def create_event!(attributes = {})
    venue_id = Venue.insert_all!([
      {
        name: "Im Wizemann",
        created_at: Time.current,
        updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first

    defaults = {
      artist_name: "Artist",
      normalized_artist_name: attributes.fetch(:artist_name, "Artist").to_s.downcase,
      title: "Tour",
      slug: SecureRandom.hex(8),
      status: "published",
      published_at: 1.day.ago,
      start_at: 1.week.from_now,
      venue_id: venue_id,
      highlighted: false,
      event_series_assignment: "auto",
      created_at: Time.current,
      updated_at: Time.current
    }

    Event.find(Event.insert_all!([ defaults.merge(attributes) ], returning: %w[id]).rows.first.first)
  end

  def create_import_event_image!(event:, image_url:)
    ImportEventImage.insert_all!([
      {
        import_class: "Event",
        import_event_id: event.id,
        source: "eventim",
        image_type: "big",
        image_url: image_url,
        role: "cover",
        aspect_hint: "square",
        position: 0,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end

  def create_event_offer!(event:, sold_out: false, metadata: {})
    EventOffer.insert_all!([
      {
        event_id: event.id,
        source: "eventim",
        source_event_id: SecureRandom.hex(4),
        ticket_url: "https://tickets.example.test/%{event_id}",
        ticket_price_text: "46,50 EUR",
        sold_out: sold_out,
        metadata: metadata,
        priority_rank: 1,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end

  def attach_test_image!(image)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image"),
      filename: "test.jpg",
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
  end
end
