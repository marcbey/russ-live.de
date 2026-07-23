require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
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

  test "signed out visitors do not see backend navigation or edit buttons" do
    create_reference_with_image!(title: "VISIBLE REFERENCE", position: 1, tag_list: "Concert")

    [ root_path, referenzen_path, jobs_path, job_path("stagehands"), unternehmen_path, team_path ].each do |path|
      get path

      assert_response :success
      assert_not_includes response.body, 'data-role="public-backend-nav-link"'
      assert_not_includes response.body, 'data-role="public-admin-edit-link"'
    end
  end

  test "backend users see backend navigation and edit buttons on editable public areas" do
    create_reference_with_image!(title: "VISIBLE REFERENCE", position: 1, tag_list: "Concert")
    admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")

    sign_in_as(admin)

    get referenzen_path

    assert_response :success
    assert_includes response.body, 'data-role="public-backend-nav-link"'
    assert_includes response.body, "href=\"#{backend_root_path}\""
    assert_includes response.body, 'data-role="public-admin-edit-link"'
    assert_includes response.body, "href=\"#{backend_references_path}\""

    get jobs_path

    assert_response :success
    assert_includes response.body, 'data-role="public-backend-nav-link"'
    assert_includes response.body, "href=\"#{backend_jobs_path}\""

    stagehands_job = Job.find_by!(slug: "stagehands")

    get job_path(stagehands_job.slug)

    assert_response :success
    assert_includes response.body, "href=\"#{backend_jobs_path(job_id: stagehands_job.id)}\""
    assert_includes response.body, "href=\"#{backend_contacts_path(contact_id: stagehands_job.contact.id)}\""
  end

  test "backend users do not see edit buttons on static public pages without backend targets" do
    admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")

    sign_in_as(admin)

    [ unternehmen_path, team_path ].each do |path|
      get path

      assert_response :success
      assert_includes response.body, 'data-role="public-backend-nav-link"'
      assert_not_includes response.body, 'data-role="public-admin-edit-link"'
    end
  end

  test "renders public pages" do
    {
      root_path => "Ihr örtlicher",
      unternehmen_path => "Veranstaltungen",
      team_path => "Michaela Russ",
      services_path => "Live",
      referenzen_path => "Projekte auf die wir stolz sind",
      jobs_path => "Aktuelle Jobangebote",
      job_path("stagehands") => "Jobdetails Stagehands",
      presse_path => "Presseinfos für",
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

  test "renders published jobs in main navigation submenu" do
    get root_path

    assert_response :success
    assert_select ".nav-submenu-jobs[aria-label=?]", "Jobangebote Untermenü" do
      assert_select "a[href=?]", jobs_path(anchor: "jobs-list"), text: "Alle Jobangebote"
      assert_select "a[href=?]", job_path("cateringhilfen"), text: "Cateringhilfen"
      assert_select "a[href=?]", job_path("stagehands"), text: "Stagehands"
    end

    get job_path("stagehands")

    assert_response :success
    assert_select ".nav-submenu-jobs a[aria-current='page'][href=?]", job_path("stagehands"), text: "Stagehands"
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
      team_path,
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

  test "renders localized legal page content" do
    get agb_path

    assert_response :success
    assert_includes response.body, "Bestellbedingungen der SKS Michael Russ GmbH"
    assert_includes response.body, "Stand: 01.07.2022"

    get datenschutz_path

    assert_response :success
    assert_includes response.body, "Host Europe"
    assert_includes response.body, "Google Analytics"

    post locale_path(:en), params: { return_to: agb_path }
    assert_redirected_to agb_path

    get agb_path

    assert_response :success
    assert_includes response.body, "Ordering conditions of SKS Michael Russ GmbH"
    assert_includes response.body, "Last updated: 1 July 2022"

    get jugendschutz_path

    assert_response :success
    assert_includes response.body, "Youth Protection"
    assert_includes response.body, "Print"
    assert_includes response.body, "Download PDF"
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

  test "homepage renders reference marquee with published square references" do
    Reference.create!(
      title: "Referenz ohne Bild",
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      featured: true,
      status: "published"
    )
    reference = create_reference_with_image!(title: "Normale Referenz", position: 1, tag_list: "Concert")

    get root_path

    assert_response :success
    assert_select ".home-references-band .reference-marquee"
    assert_select ".home-references-band .reference-marquee-cta .reference-marquee-detail-button[href=?]", referenzen_path, count: 1
    assert_select ".home-references-band .reference-marquee-card .reference-marquee-detail-button", count: 0
    assert_not_includes response.body, "Referenz ohne Bild"
    assert_includes response.body, "Normale Referenz"
    assert_match %r{01-disgusting-food-museum-[a-f0-9]+\.jpg}, response.body
    assert_select ".home-references-band .klassik-slider", count: 0
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

    reference.update!(featured: true)
    get root_path

    assert_response :success
    assert_includes response.body, "object-position: 35.0% 65.0%"
    assert_includes response.body, "--reference-image-focus-x: 35.0%"
    assert_includes response.body, "--reference-image-focus-y: 65.0%"
    assert_includes response.body, "--reference-image-zoom: 1.45"
    assert_select ".home-references-band .reference-marquee-cta .reference-marquee-detail-button[href=?]", referenzen_path, count: 1
  end

  test "homepage uses square reference image instead of dedicated slider image" do
    reference = Reference.create!(
      title: "NEIL YOUNG",
      starts_on: Date.new(2024, 6, 29),
      location: "Hanns-Martin-Schleyer-Halle",
      production: "Wizart Promotion",
      status: "published",
      featured: true,
      position: 1
    )
    reference.create_reference_image!(
      asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
      alt_text: "Main Alt",
      slider_asset_path: "russ_live/references/03-neil-young.jpg",
      slider_alt_text: "Slider Alt"
    )

    get root_path

    assert_response :success
    assert_match %r{01-disgusting-food-museum-[a-f0-9]+\.jpg}, response.body
    assert_no_match %r{03-neil-young-[a-f0-9]+\.jpg}, response.body
    assert_not_includes response.body, "variant=slider"
    assert_not_includes response.body, "Slider Alt"
    assert_select ".home-references-band .reference-marquee-card .reference-marquee-front[data-reference-image-render-target=?]", "frame"
    assert_select ".home-references-band .reference-marquee-card .reference-marquee-back .reference-card-name", "NEIL YOUNG"
    assert_select ".home-references-band .reference-marquee-card .reference-marquee-detail-button", count: 0
    assert_select ".home-references-band .reference-marquee-cta .reference-marquee-detail-button", "Zur Referenzseite"
    assert_select ".home-references-band .klassik-slider-meta", count: 0
  end

  test "homepage skips references with slider image only" do
    reference = Reference.create!(
      title: "SLIDER ONLY",
      starts_on: Date.new(2024, 6, 29),
      location: "Hanns-Martin-Schleyer-Halle",
      production: "Wizart Promotion",
      status: "published",
      featured: true,
      position: 1
    )
    reference.create_reference_image!(
      slider_asset_path: "russ_live/references/03-neil-young.jpg",
      slider_alt_text: "Nur Slider Alt"
    )

    get root_path

    assert_response :success
    assert_select ".home-references-band", count: 0
    assert_not_includes response.body, "SLIDER ONLY"
    assert_no_match %r{03-neil-young-[a-f0-9]+\.jpg}, response.body
    assert_not_includes response.body, "Nur Slider Alt"
  end

  test "homepage reference marquee overview button links to reference page" do
    first = create_reference_with_image!(title: "ERSTES PROJEKT", position: 2, tag_list: "Festival", featured: true)
    second = create_reference_with_image!(title: "ZWEITES PROJEKT", position: 1, tag_list: "Open Air", featured: true)
    first.reference_image.update!(slider_asset_path: "russ_live/references/02-david-garrett.jpg", slider_badge_text: "Festival")
    second.reference_image.update!(slider_asset_path: "russ_live/references/03-neil-young.jpg", slider_badge_text: "Open Air")

    get root_path

    assert_response :success
    assert_select ".home-references-band .reference-marquee-card[href]", count: 0
    assert_select ".home-references-band .reference-marquee-card .reference-marquee-detail-button", count: 0
    assert_select ".home-references-band .reference-marquee-cta .reference-marquee-detail-button[href=?]", referenzen_path, count: 1
    assert_select ".home-references-band .reference-marquee-cta .reference-marquee-detail-button", "Zur Referenzseite"
    assert_select ".home-references-band .klassik-slide-badge", count: 0
    assert_not_includes response.body, "Festival"
    assert_not_includes response.body, "Open Air"

    get referenzen_path(reference_id: second.id)

    assert_response :success
    assert_select "#referenz-highlights"
    assert_select ".reference-hero-slider[data-controller=?]", "reference-hero-slider"
    assert_select ".reference-hero-slider .reference-hero-slide-copy h2", text: second.title
    assert_select ".reference-hero-slider .reference-hero-slide-copy h2", text: first.title
    assert_select ".reference-featured-marquee", count: 0
    assert_select ".reference-featured-slider", count: 0
    assert_operator response.body.index("ZWEITES PROJEKT"), :<, response.body.index("ERSTES PROJEKT")
    assert_match %r{03-neil-young-[a-f0-9]+\.jpg}, response.body
    assert_match %r{02-david-garrett-[a-f0-9]+\.jpg}, response.body
  end

  test "homepage renders normal reference image when no slider image exists" do
    reference = Reference.create!(
      title: "NEIL YOUNG",
      starts_on: Date.new(2024, 6, 29),
      location: "Hanns-Martin-Schleyer-Halle",
      production: "Wizart Promotion",
      status: "published",
      featured: true,
      position: 1
    )
    reference.create_reference_image!(
      asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
      alt_text: "Main Alt",
      card_focus_x: 35,
      card_focus_y: 65,
      card_zoom: 145
    )

    get root_path

    assert_response :success
    assert_match %r{01-disgusting-food-museum-[a-f0-9]+\.jpg}, response.body
    assert_includes response.body, "--reference-image-focus-x: 35.0%"
    assert_includes response.body, "--reference-image-focus-y: 65.0%"
    assert_includes response.body, "--reference-image-zoom: 1.45"
  end

  test "homepage ignores uploaded slider image when normal reference image is available" do
    reference = Reference.create!(
      title: "NEIL YOUNG",
      starts_on: Date.new(2024, 6, 29),
      location: "Hanns-Martin-Schleyer-Halle",
      production: "Wizart Promotion",
      status: "published",
      featured: true,
      position: 1
    )
    reference_image = reference.create_reference_image!(
      asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
      alt_text: "Main Alt"
    )
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/references/03-neil-young.jpg"),
      "image/jpeg"
    )
    reference_image.write_uploaded_file!(upload, variant: ReferenceImage::SLIDER_VARIANT)
    reference_image.update!(slider_alt_text: "Uploaded Slider Alt")

    get root_path

    assert_response :success
    assert_match %r{01-disgusting-food-museum-[a-f0-9]+\.jpg}, response.body
    assert_not_includes response.body, "/referenzbilder/#{reference_image.id}"
    assert_not_includes response.body, "variant=slider"
    assert_not_includes response.body, "Uploaded Slider Alt"
  end

  test "public reference surfaces prefer freeform display date when present" do
    reference = Reference.create!(
      title: "AUSSTELLUNG",
      starts_on: Date.new(2025, 6, 1),
      display_date: "Juni 2025 - März 2026",
      location: "Museum",
      status: "published",
      featured: true,
      position: 1
    )
    reference.create_reference_image!(
      asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
      alt_text: "AUSSTELLUNG"
    )

    get referenzen_path

    assert_response :success
    assert_includes response.body, "Juni 2025 - März 2026"
    assert_not_includes response.body, "01.06.2025</span>"

    get root_path

    assert_response :success
    assert_not_includes response.body, "Juni 2025 - März 2026 · Museum"
    assert_select ".home-references-band .reference-marquee-cta .reference-marquee-detail-button[href=?]", referenzen_path, count: 1
  end

  test "reference page renders featured slider references as full width hero slider and again in square regular grid" do
    featured = create_reference_with_image!(
      title: "HAUPTPROJEKT",
      position: 2,
      tag_list: "Festival",
      featured: true,
      description: "Eine große Referenz mit Sliderbild."
    )
    featured.update!(production: "Russ Live Produktion")
    featured.reference_image.update!(
      grid_variant: "2x2",
      slider_asset_path: "russ_live/references/03-neil-young.jpg",
      slider_mobile_asset_path: "russ_live/references/02-david-garrett.jpg",
      slider_alt_text: "Hauptprojekt Slider"
    )
    featured_without_slider = create_reference_with_image!(title: "FEATURED OHNE SLIDER", position: 3, tag_list: "Theater", featured: true)
    regular = create_reference_with_image!(title: "NORMALE KACHEL", position: 1, tag_list: "Open Air")
    regular.reference_image.update!(grid_variant: "2x2")

    get referenzen_path

    assert_response :success
    assert_select ".references-featured-band .references-featured-heading", count: 0
    assert_select ".reference-hero-slider[data-controller=?]", "reference-hero-slider"
    assert_select ".reference-hero-slider .reference-hero-slide", count: 1
    assert_select ".reference-hero-slider .reference-hero-slide-copy h2", text: "HAUPTPROJEKT"
    assert_select ".reference-hero-slider .reference-hero-slide-copy", text: /Stuttgart/
    assert_select ".reference-hero-slider .reference-hero-slide-copy", text: /#{Regexp.escape(featured.display_date_text)}/
    assert_select ".reference-hero-slider .reference-hero-slide-copy", text: /Russ Live Produktion/
    assert_select ".reference-hero-slider .reference-hero-slide-copy", text: /Eine große Referenz mit Sliderbild/
    assert_select ".reference-hero-slider .reference-hero-slide-copy h2", text: "FEATURED OHNE SLIDER", count: 0
    assert_select ".reference-hero-slider .reference-hero-slider-controls", count: 0
    assert_select ".reference-featured-marquee", count: 0
    assert_select ".reference-featured-slider", count: 0
    assert_operator response.body.index("reference-hero-slider"), :<, response.body.index("references-filter-band")
    assert_operator response.body.index("references-filter-band"), :<, response.body.index("reference-highlight-grid")
    assert_operator response.body.index("references-intro"), :<, response.body.index("reference-highlight-grid")
    assert_select ".references-intro #references-title", text: I18n.t("pages.references.hero.title")
    assert_select ".references-intro p", text: I18n.t("pages.references.hero.intro")
    assert_match %r{03-neil-young-[a-f0-9]+\.jpg}, response.body
    assert_select ".reference-hero-slider picture source[media=?]", "(max-width: 760px)", count: 1 do |sources|
      assert_match %r{02-david-garrett-[a-f0-9]+\.jpg}, sources.first["srcset"]
    end
    assert_select ".reference-hero-slider picture img[src*=?]", "03-neil-young", count: 1
    assert_includes response.body, "Hauptprojekt Slider"
    assert_select ".klassik-slider-meta", count: 0
    assert_select ".reference-highlight-grid .reference-card-name", text: featured.title
    assert_select ".reference-highlight-grid .reference-card-name", text: featured_without_slider.title
    assert_select ".reference-highlight-grid .reference-card-name", text: regular.title
    assert_select ".reference-highlight-grid .reference-card-grid-2-2", count: 0
    assert_select ".reference-highlight-grid .reference-card-grid-1-1", count: 3
    assert_includes response.body, 'data-reference-tag="open-air"'
    assert_includes response.body, 'data-reference-tag="festival"'
    assert_includes response.body, 'data-reference-tag="theater"'
  end

  test "reference page falls back to static hero when no featured slider images exist" do
    reference = create_reference_with_image!(title: "NUR KACHEL", position: 1, tag_list: "Ausstellung", featured: true)

    get referenzen_path

    assert_response :success
    assert_select ".references-hero-static"
    assert_select ".reference-hero-slider", count: 0
    assert_select ".references-intro #references-title", text: I18n.t("pages.references.hero.title")
    assert_operator response.body.index("references-intro"), :<, response.body.index("reference-highlight-grid")
    assert_select ".reference-highlight-grid .reference-card-name", text: reference.title
  end

  test "services omits reference slider even with published concert references" do
    concert = create_reference_with_image!(title: "CONCERT", position: 1, tag_list: "concert")
    create_reference_with_image!(title: "KONZERT", position: 2, tag_list: "Konzert")
    create_reference_with_image!(title: "LIVE", position: 3, tag_list: "Live")

    get services_path

    assert_response :success
    assert_not_includes response.body, "services-showcase"
    assert_not_includes response.body, "services-reference-slider"
    assert_not_includes response.body, concert.title
    assert_not_includes response.body, "KONZERT"
    assert_not_includes response.body, "LIVE"
    assert_not_includes response.body, "/assets/russ_live/references/01-disgusting-food-museum"
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
    assert_includes response.body, 'href="#job-application"'
    assert_includes response.body, 'data-controller="job-application-mail"'
    assert_includes response.body, 'data-job-application-mail-greeting-value="Hallo Sebastian,"'
    assert_includes response.body, 'data-job-application-mail-interest-line-value="Ich interessiere mich für die Stelle Stagehands."'
    assert_includes response.body, 'data-job-application-mail-personal-details-heading-value="Meine Daten:"'
    assert_includes response.body, 'id="job_application_salutation"'
    assert_includes response.body, 'id="job_application_first_name"'
    assert_includes response.body, 'id="job_application_last_name"'
    assert_includes response.body, 'id="job_application_address"'
    assert_includes response.body, 'id="job_application_city"'
    assert_includes response.body, 'id="job_application_phone"'
    assert_includes response.body, 'id="job_application_email"'
    assert_includes response.body, 'id="job_application_position"'
    assert_includes response.body, 'id="job_application_message"'
    assert_includes response.body, "Erzähle uns etwas von dir"
    assert_includes response.body, "Es wird eine E-Mail vorbereitet."
    assert_includes response.body, "Anschreiben, Zeugnisse und Lebenslauf"
  end

  test "jobs overview links to separate job pages" do
    get jobs_path

    assert_response :success
    assert_includes response.body, job_path("cateringhilfen")
    assert_includes response.body, job_path("stagehands")
    assert_no_match(/Jobdetails Stagehands/, response.body)
  end

  test "jobs overview hides draft jobs and renders category metadata on cards" do
    Job.create!(
      title: "Draft Job",
      slug: "draft-job",
      location: "Stuttgart",
      status: "draft",
      category_list: "Intern"
    )

    get jobs_path

    assert_response :success
    assert_includes response.body, 'data-job-categories="catering"'
    assert_includes response.body, 'class="public-directory job-table"'
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

  def create_reference_with_image!(title:, position:, tag_list:, status: "published", featured: false, description: nil, description_en: nil)
    Reference.create!(
      title: title,
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      status: status,
      featured: featured,
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
