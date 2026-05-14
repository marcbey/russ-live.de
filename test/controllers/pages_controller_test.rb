require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    clear_stuttgart_live_records
    seed_sks_promoter_ids!
  end

  test "renders public pages" do
    {
      root_path => "Ihr örtlicher",
      unternehmen_path => "Veranstaltungen",
      services_path => "Live",
      referenzen_path => "Projekte, Projekte, Projekte",
      jobs_path => "Unsere aktuellen Jobangebote",
      job_path("stagehands") => "Jobdetails Stagehands",
      presse_path => "Presseinfos für Partner und Medien.",
      kontakt_path => "Charlottenplatz 17",
      impressum_path => "Impressum",
      datenschutz_path => "Datenschutz",
      agb_path => "AGB",
      jugendschutz_path => "Jugendschutz"
    }.each do |path, text|
      get path

      assert_response :success
      assert_includes response.body, text
      assert_includes response.body, "/assets/russ_live/"
    end
  end

  test "renders job detail on its own page" do
    get job_path("stagehands")

    assert_response :success
    assert_includes response.body, "Stagehands"
    assert_includes response.body, "Jobdetails Stagehands"
    assert_includes response.body, "Auf- und Abbau von Bühnen-, Licht- und Tontechnik"
  end

  test "jobs overview links to separate job pages" do
    get jobs_path

    assert_response :success
    assert_includes response.body, job_path("cateringhilfen")
    assert_includes response.body, job_path("stagehands")
    assert_no_match(/Jobdetails Stagehands/, response.body)
  end

  test "homepage renders sks highlights from Stuttgart Live with lazy images" do
    matching_event = create_event!(
      artist_name: "WILHELMINE",
      title: "magisch Tour 2026",
      promoter_id: "10135",
      start_at: 2.days.from_now
    )
    create_import_event_image!(event: matching_event, image_url: "https://img.example.test/wilhelmine.jpg")
    create_event_offer!(event: matching_event, ticket_url: "https://tickets.example.test/%{event_id}", source_event_id: "evt-1")
    create_event!(artist_name: "Other", title: "Nicht SKS", promoter_id: "99999", start_at: 3.days.from_now)
    create_event!(artist_name: "Manual", title: "Highlight ohne SKS", promoter_id: "99999", highlighted: true, start_at: 4.days.from_now)
    create_event!(artist_name: "Past", title: "Vergangen", promoter_id: "10135", start_at: 1.day.ago)
    create_event!(artist_name: "Draft", title: "Unveröffentlicht", promoter_id: "10135", status: "ready_for_publish", start_at: 5.days.from_now)

    get root_path

    assert_response :success
    assert_includes response.body, "WILHELMINE"
    assert_includes response.body, "magisch Tour 2026"
    assert_includes response.body, "https://img.example.test/wilhelmine.jpg"
    assert_includes response.body, 'loading="lazy"'
    assert_includes response.body, 'decoding="async"'
    assert_includes response.body, "https://tickets.example.test/evt-1"
    assert_not_includes response.body, "Nicht SKS"
    assert_not_includes response.body, "Highlight ohne SKS"
    assert_not_includes response.body, "Vergangen"
    assert_not_includes response.body, "Unveröffentlicht"
  end

  test "homepage deduplicates event series" do
    create_event!(artist_name: "Series A", title: "Termin 1", promoter_id: "10135", event_series_id: 42, start_at: 2.days.from_now)
    create_event!(artist_name: "Series A", title: "Termin 2", promoter_id: "10135", event_series_id: 42, start_at: 3.days.from_now)

    get root_path

    assert_response :success
    assert_includes response.body, "Termin 1"
    assert_not_includes response.body, "Termin 2"
  end

  test "homepage lane endpoint renders cursor pages without duplicates" do
    events = 12.times.map do |index|
      create_event!(
        artist_name: "Lane Artist #{index}",
        title: "Lane Event #{index}",
        promoter_id: "10135",
        start_at: (index + 1).days.from_now
      )
    end

    get homepage_lane_events_path(per_page: 5)

    assert_response :success
    assert_includes response.body, "Lane Event 0"
    assert_includes response.body, "Lane Event 4"
    assert_not_includes response.body, "Lane Event 5"
    cursor = response.headers.fetch("X-Homepage-Lane-Next-Cursor")
    assert_predicate cursor, :present?
    assert_equal "true", response.headers["X-Homepage-Lane-Has-More"]

    get homepage_lane_events_path(cursor: cursor, per_page: 5)

    assert_response :success
    assert_not_includes response.body, events.first.title
    assert_includes response.body, "Lane Event 5"
    assert_includes response.body, "Lane Event 9"
  end

  test "homepage lane endpoint rejects invalid cursors" do
    get homepage_lane_events_path(cursor: "not-a-valid-cursor")

    assert_response :bad_request
  end

  private

  def clear_stuttgart_live_records
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
    ActionText::RichText.delete_all
    EventOffer.delete_all
    EventImage.delete_all
    ImportEventImage.delete_all
    Event.delete_all
    Venue.delete_all
    AppSetting.delete_all
  end

  def seed_sks_promoter_ids!
    AppSetting.insert_all!([
      {
        key: AppSetting::SKS_PROMOTER_IDS_KEY,
        value: %w[10135 10136 382],
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end

  def create_event!(attributes = {})
    venue = Venue.insert_all!([
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
      venue_id: venue,
      highlighted: false,
      event_series_assignment: "auto",
      created_at: Time.current,
      updated_at: Time.current
    }

    id = Event.insert_all!([ defaults.merge(attributes) ], returning: %w[id]).rows.first.first
    Event.find(id)
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

  def create_event_offer!(event:, ticket_url:, source_event_id:, sold_out: false, metadata: {})
    EventOffer.insert_all!([
      {
        event_id: event.id,
        source: "eventim",
        source_event_id: source_event_id,
        ticket_url: ticket_url,
        ticket_price_text: "46,50 EUR",
        sold_out: sold_out,
        metadata: metadata,
        priority_rank: 1,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
  end
end
