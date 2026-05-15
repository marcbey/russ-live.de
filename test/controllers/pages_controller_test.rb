require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    JobImage.delete_all
    Job.delete_all
    ContactImage.delete_all
    Contact.delete_all
    ReferenceImage.delete_all
    Reference.delete_all
    clear_stuttgart_live_records
    seed_sks_promoter_ids!
    seed_jobs!
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

  test "sets english locale by cookie" do
    post locale_path(:en), params: { return_to: root_path }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_includes response.body, "Your local promoter for Stuttgart"
    assert_includes response.body, "href=\"/services\""
    assert_not_includes response.body, "?locale="
  end

  test "renders all public pages in english without missing translation markers" do
    post locale_path(:en), params: { return_to: root_path }
    assert_redirected_to root_path

    [
      root_path,
      unternehmen_path,
      services_path,
      referenzen_path,
      jobs_path,
      job_path("stagehands"),
      presse_path,
      kontakt_path,
      impressum_path,
      datenschutz_path,
      agb_path,
      jugendschutz_path
    ].each do |path|
      get path

      assert_response :success
      assert_select "html[lang=?]", "en"
      assert_not_includes response.body, "translation missing"
    end
  end

  test "sets german locale by cookie" do
    post locale_path(:de), params: { return_to: root_path }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "html[lang=?]", "de"
    assert_includes response.body, "Ihr örtlicher Veranstalter für Stuttgart"
    assert_includes response.body, "href=\"/services\""
    assert_not_includes response.body, "?locale="
  end

  test "uses english browser language without query parameter" do
    get root_path, headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9,de;q=0.5" }

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_includes response.body, "Your local promoter for Stuttgart"
    assert_not_includes response.body, "href=\"/services?locale=en\""
  end

  test "falls back to german without matching locale" do
    get root_path, headers: { "HTTP_ACCEPT_LANGUAGE" => "fr-FR,fr;q=0.9" }

    assert_response :success
    assert_select "html[lang=?]", "de"
    assert_includes response.body, "Ihr örtlicher Veranstalter für Stuttgart"
  end

  test "invalid locale query parameter is removed without setting locale" do
    get root_path(locale: :fr), headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "html[lang=?]", "de"
    assert_includes response.body, "Ihr örtlicher Veranstalter für Stuttgart"
    assert_not_includes response.body, "?locale=fr"
  end

  test "legacy locale query parameter sets cookie and redirects to clean url" do
    get root_path(locale: :en)

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_includes response.body, "Your local promoter for Stuttgart"
    assert_not_includes response.body, "?locale="
  end

  test "language switch posts current route and non-locale query parameters without visible locale" do
    post locale_path(:en), params: { return_to: jobs_path(category: "catering") }
    assert_redirected_to jobs_path(category: "catering")

    get jobs_path(category: "catering")

    assert_response :success
    assert_includes response.body, "action=\"/language/de\""
    assert_includes response.body, "action=\"/language/en\""
    assert_includes response.body, "value=\"/jobs?category=catering\""
    assert_not_includes response.body, "locale="
  end

  test "homepage omits reference slider without published references with images" do
    Reference.create!(
      title: "Referenz ohne Bild",
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      status: "published"
    )

    get root_path

    assert_response :success
    assert_not_includes response.body, "home-references-band"
    assert_not_includes response.body, "Referenz ohne Bild"
    assert_not_includes response.body, "DISGUSTING FOOD MUSEUM"
  end

  test "renders reference image crop and zoom styles on public reference surfaces" do
    reference = Reference.create!(
      title: "NEIL YOUNG",
      starts_on: Date.new(2024, 6, 29),
      location: "Hanns-Martin-Schleyer-Halle",
      production: "Wizart Promotion",
      status: "published",
      position: 1
    )
    reference.create_reference_image!(
      asset_path: "russ_live/references/03-neil-young.jpg",
      alt_text: "NEIL YOUNG",
      grid_variant: "2x2",
      card_focus_x: 35,
      card_focus_y: 65,
      card_zoom: 145
    )

    get referenzen_path

    assert_response :success
    assert_includes response.body, "object-position: 35.0% 65.0%"
    assert_includes response.body, "--reference-image-focus-x: 35.0%"
    assert_includes response.body, "--reference-image-focus-y: 65.0%"
    assert_includes response.body, "--reference-image-zoom: 1.45"
    assert_includes response.body, 'data-controller="reference-image-render"'
    assert_includes response.body, 'data-reference-image-render-focus-x-value="35.0"'
    assert_includes response.body, 'data-reference-image-render-focus-y-value="65.0"'
    assert_includes response.body, 'data-reference-image-render-zoom-value="145.0"'
    assert_includes response.body, 'data-reference-image-render-target="frame"'

    get root_path

    assert_response :success
    assert_includes response.body, "object-position: 35.0% 65.0%"
    assert_includes response.body, "--reference-image-focus-x: 35.0%"
    assert_includes response.body, "--reference-image-focus-y: 65.0%"
    assert_includes response.body, "--reference-image-zoom: 1.45"
    assert_includes response.body, 'data-controller="reference-image-render"'
    assert_includes response.body, 'data-reference-image-render-focus-x-value="35.0"'
    assert_includes response.body, 'data-reference-image-render-focus-y-value="65.0"'
    assert_includes response.body, 'data-reference-image-render-zoom-value="145.0"'
    assert_includes response.body, 'data-reference-image-render-target="frame"'
  end

  test "services renders reference slider for published image references with concert tags" do
    concert = create_reference_with_image!(title: "CONCERT", position: 1, tag_list: "concert")
    create_reference_with_image!(title: "KONZERT", position: 2, tag_list: "Konzert")
    create_reference_with_image!(title: "LIVE", position: 3, tag_list: "Live")
    create_reference_with_image!(title: "LIVEHOUSE", position: 4, tag_list: "Livehouse")
    create_reference_with_image!(title: "OPEN AIR", position: 5, tag_list: "Open Air")
    create_reference_with_image!(title: "DRAFT CONCERT", status: "draft", position: 6, tag_list: "Concert")
    Reference.create!(
      title: "CONCERT WITHOUT IMAGE",
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      status: "published",
      position: 7,
      tag_list: "Concert"
    )

    get services_path

    assert_response :success
    assert_includes response.body, "services-showcase"
    assert_includes response.body, "services-reference-slider"
    assert_includes response.body, concert.title
    assert_includes response.body, "KONZERT"
    assert_includes response.body, "LIVE"
    assert_includes response.body, "/assets/russ_live/references/01-disgusting-food-museum"
    assert_not_includes response.body, "LIVEHOUSE"
    assert_not_includes response.body, "OPEN AIR"
    assert_not_includes response.body, "DRAFT CONCERT"
    assert_not_includes response.body, "CONCERT WITHOUT IMAGE"
    assert_not_includes response.body, "Five Finger Death Punch"
    assert_not_includes response.body, "russ_live/references/featured/bild1.jpg"
  end

  test "services omits reference slider without matching concert references" do
    create_reference_with_image!(title: "OPEN AIR", position: 1, tag_list: "Open Air")
    Reference.create!(
      title: "CONCERT WITHOUT IMAGE",
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      status: "published",
      position: 2,
      tag_list: "Concert"
    )

    get services_path

    assert_response :success
    assert_not_includes response.body, "services-showcase"
    assert_not_includes response.body, "services-reference-slider"
    assert_not_includes response.body, "OPEN AIR"
    assert_not_includes response.body, "CONCERT WITHOUT IMAGE"
  end

  test "renders public references with tag filters instead of year filters" do
    open_air = Reference.create!(
      title: "OPEN AIR SHOW",
      starts_on: Date.new(2025, 7, 1),
      location: "Schlossplatz Stuttgart",
      status: "published",
      position: 1,
      tag_list: "Open Air, Clubkonzert"
    )
    open_air.create_reference_image!(asset_path: "russ_live/references/01-disgusting-food-museum.jpg", alt_text: open_air.title)
    exhibition = Reference.create!(
      title: "AUSSTELLUNG",
      starts_on: Date.new(2024, 5, 1),
      location: "Museum",
      status: "published",
      position: 2,
      tag_list: "Ausstellung"
    )
    exhibition.create_reference_image!(asset_path: "russ_live/references/02-david-garrett.jpg", alt_text: exhibition.title)
    draft = Reference.create!(
      title: "DRAFT",
      starts_on: Date.new(2026, 1, 1),
      location: "Stuttgart",
      status: "draft",
      position: 3,
      tag_list: "Intern"
    )
    draft.create_reference_image!(asset_path: "russ_live/references/03-neil-young.jpg", alt_text: draft.title)

    get referenzen_path

    assert_response :success
    assert_includes response.body, 'class="public-filter-nav references-filter-nav"'
    assert_includes response.body, 'data-reference-tag="all"'
    assert_includes response.body, 'data-reference-tag="open-air"'
    assert_includes response.body, 'data-reference-tag="clubkonzert"'
    assert_includes response.body, 'data-reference-tag="ausstellung"'
    assert_includes response.body, 'data-reference-tags="open-air clubkonzert"'
    assert_not_includes response.body, "references-year-nav"
    assert_not_includes response.body, "data-year"
    assert_not_includes response.body, "Intern"
  end

  test "renders localized reference descriptions" do
    localized = create_reference_with_image!(
      title: "LOCALIZED SHOW",
      position: 1,
      tag_list: "Open Air",
      description: "Deutsche Referenzbeschreibung",
      description_en: "English reference description"
    )
    fallback = create_reference_with_image!(
      title: "FALLBACK SHOW",
      position: 2,
      tag_list: "Clubkonzert",
      description: "Deutsche Fallback-Beschreibung"
    )

    get referenzen_path

    assert_response :success
    assert_includes response.body, localized.description
    assert_includes response.body, fallback.description
    assert_not_includes response.body, localized.description_en

    post locale_path(:en), params: { return_to: referenzen_path }
    assert_redirected_to referenzen_path

    get referenzen_path

    assert_response :success
    assert_includes response.body, localized.description_en
    assert_includes response.body, fallback.description
    assert_not_includes response.body, localized.description
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

  test "jobs overview renders category filters and hides draft jobs" do
    Job.create!(
      title: "Draft Job",
      slug: "draft-job",
      location: "Stuttgart",
      status: "draft",
      category_list: "Intern"
    )

    get jobs_path

    assert_response :success
    assert_includes response.body, 'class="public-filter-nav job-category-filter-nav"'
    assert_includes response.body, 'data-job-category="catering"'
    assert_includes response.body, 'data-job-categories="catering"'
    assert_not_includes response.body, "Intern"
    assert_not_includes response.body, "Draft Job"
  end

  test "job detail has contact sidebar but no category or profile filters" do
    get job_path("stagehands")

    assert_response :success
    assert_not_includes response.body, "job-category-filter-nav"
    assert_not_includes response.body, "job-profile-nav"
    assert_includes response.body, "job-sidebar"
    assert_includes response.body, "Sebastian Kränzlein"
    assert_includes response.body, 'href="tel:+497111635342"'
    assert_includes response.body, "mailto:sebastiankraenzlein@russ-live.de?subject=Bewerbung%20Stagehands"
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

    post locale_path(:en), params: { return_to: root_path }
    assert_redirected_to root_path

    get root_path

    assert_response :success
    assert_includes response.body, "data-events-slider-url-value=\"/events/homepage_lane\""
    assert_not_includes response.body, "data-events-slider-url-value=\"/events/homepage_lane?locale="
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

  def seed_jobs!
    contact = Contact.create!(
      name: "Sebastian Kränzlein",
      role: "Personaldisposition / Personalmarketing",
      phone_number: "+49.711.16 353 42",
      email: "sebastiankraenzlein@russ-live.de",
      position: 1
    )
    contact.create_contact_image!(asset_path: "russ_live/team/sebastian-kraenzlein.jpg", alt_text: contact.name)

    [
      [ "cateringhilfen", "Cateringhilfen", "Catering" ],
      [ "stagehands", "Stagehands", "Auf-/Abbau" ]
    ].each_with_index do |(slug, title, category), index|
      job = Job.create!(
        contact: contact,
        slug: slug,
        title: title,
        badge: "Minijob",
        employment: "Flexible Einsätze bei Konzerten und Produktionen, m/w/d",
        category_list: category,
        location: "Stuttgart",
        intro: "Du unterstützt unser Team hinter den Kulissen.",
        responsibilities_text: "Unterstützung beim Auf- und Abbau von Bühnen-, Licht- und Tontechnik\nTransport und Positionierung von Material im Venue",
        requirements_text: "Teamfähigkeit\nZuverlässigkeit",
        status: "published",
        position: index + 1
      )
      job.create_job_image!(asset_path: "russ_live/jobs/cateringhilfen.jpg", alt_text: title)
    end
  end

  def create_reference_with_image!(title:, position:, tag_list:, status: "published", description: nil, description_en: nil)
    Reference.create!(
      title: title,
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      status: status,
      position: position,
      tag_list: tag_list,
      description: description,
      description_en: description_en
    ).tap do |reference|
      reference.create_reference_image!(
        asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
        alt_text: reference.title
      )
    end
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
