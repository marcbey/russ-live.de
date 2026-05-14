require_dependency Rails.root.join("app/services/home_events_lane_pager").to_s

class PagesController < ApplicationController
  PAGE_META = {
    home: {
      title: "Russ Live | Kulturproduktionen auf höchstem Niveau",
      description: "Russ Live ist örtlicher Veranstalter, Produktionspartner und Full-Service-Dienstleister für Live Entertainment in Stuttgart und der Region.",
      body_class: "home-body"
    },
    unternehmen: {
      title: "Über uns | Russ Live",
      description: "Über Russ Live: Geschichte, Haltung und Menschen hinter den Veranstaltungen."
    },
    services: {
      title: "Services | Russ Live",
      body_class: "services-body"
    },
    referenzen: {
      title: "Referenzen | Russ Live",
      body_class: "references-body"
    },
    jobs: {
      title: "Jobs | Russ Live",
      description: "Flexible Jobs bei Konzerten, Festivals und Events in Stuttgart. Jetzt offene Stellen bei Russ Live entdecken.",
      body_class: "jobs-body jobs-overview-body"
    },
    job: {
      title: "Jobs | Russ Live",
      description: "Jobprofil bei Russ Live.",
      body_class: "jobs-body job-detail-page-body"
    },
    kontakt: {
      title: "Kontakt | Russ Live",
      description: "Kontakt zur SKS Michael Russ GmbH am Charlottenplatz in Stuttgart."
    },
    impressum: {
      title: "Impressum | Russ Live",
      description: "Impressum der SKS Michael Russ GmbH."
    },
    datenschutz: {
      title: "Datenschutz | Russ Live",
      description: "Datenschutz der SKS Michael Russ GmbH."
    },
    agb: {
      title: "AGB | Russ Live",
      description: "AGB der SKS Michael Russ GmbH."
    },
    jugendschutz: {
      title: "Jugendschutz | Russ Live",
      description: "Jugendschutz der SKS Michael Russ GmbH."
    }
  }.freeze

  HOME_REFERENCES = [
    { image: "russ_live/references/01-disgusting-food-museum.jpg", alt: "DISGUSTING FOOD MUSEUM", title: "DISGUSTING FOOD MUSEUM", date_location: "18.04.2026 · Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/02-david-garrett.jpg", alt: "DAVID GARRETT", title: "DAVID GARRETT", date_location: "21.05.2025 · Liederhalle Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/03-neil-young.jpg", alt: "NEIL YOUNG", title: "NEIL YOUNG", date_location: "29.06.2024 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/04-iron-maiden.jpg", alt: "IRON MAIDEN", title: "IRON MAIDEN", date_location: "13.07.2023 · Porsche-Arena Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/05-referenz-5.jpg", alt: "Referenz 5", title: "Referenz 5", date_location: "24.08.2022 · SpardaWelt Freilichtbühne", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/06-tate-mc-rae.jpg", alt: "TATE MC RAE", title: "TATE MC RAE", date_location: "05.09.2021 · Kultur- und Kongresszentrum", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/07-sean-paul.jpg", alt: "SEAN PAUL", title: "SEAN PAUL", date_location: "17.10.2020 · Schlossplatz Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/08-chris-tall.jpg", alt: "CHRIS TALL", title: "CHRIS TALL", date_location: "28.11.2026 · Theaterhaus Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/09-max-giesinger.jpg", alt: "MAX GIESINGER", title: "MAX GIESINGER", date_location: "18.04.2025 · Stuttgart", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/10-simply-red.jpg", alt: "SIMPLY RED", title: "SIMPLY RED", date_location: "21.05.2024 · Liederhalle Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/11-toto.jpg", alt: "TOTO", title: "TOTO", date_location: "29.06.2023 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/12-acdc.jpg", alt: "ACDC", title: "ACDC", date_location: "13.07.2022 · Porsche-Arena Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/13-gianna-nannini.jpg", alt: "GIANNA NANNINI", title: "GIANNA NANNINI", date_location: "24.08.2021 · SpardaWelt Freilichtbühne", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/14-bob-dylan.jpg", alt: "BOB DYLAN", title: "BOB DYLAN", date_location: "05.09.2020 · Kultur- und Kongresszentrum", partner: "Partner: Live Nation" },
    { image: "russ_live/references/15-laura-pausini.jpg", alt: "LAURA PAUSINI", title: "LAURA PAUSINI", date_location: "17.10.2026 · Schlossplatz Stuttgart", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/16-titanic.jpg", alt: "TITANIC", title: "TITANIC", date_location: "28.11.2025 · Theaterhaus Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/17-mamma-mia.jpg", alt: "MAMMA MIA!", title: "MAMMA MIA!", date_location: "18.04.2024 · Stuttgart", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/18-adel-tawil.jpg", alt: "ADEL TAWIL", title: "ADEL TAWIL", date_location: "21.05.2023 · Liederhalle Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/19-blue-man-group.jpg", alt: "BLUE MAN GROUP", title: "BLUE MAN GROUP", date_location: "29.06.2022 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/20-crystal-cirque-du-soleil.jpg", alt: "CRYSTAL - CIRQUE DU SOLEIL", title: "CRYSTAL - CIRQUE DU SOLEIL", date_location: "13.07.2021 · Porsche-Arena Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/21-helene-fischer.jpg", alt: "HELENE FISCHER", title: "HELENE FISCHER", date_location: "24.08.2020 · SpardaWelt Freilichtbühne", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/22-stuttgart-live-festival.png", alt: "STUTTGART-LIVE FESTIVAL", title: "STUTTGART-LIVE FESTIVAL", date_location: "05.09.2026 · Kultur- und Kongresszentrum", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/23-referenz-23.jpg", alt: "Referenz 23", title: "Referenz 23", date_location: "17.10.2025 · Schlossplatz Stuttgart", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/24-cypress-hill.jpg", alt: "CYPRESS HILL", title: "CYPRESS HILL", date_location: "28.11.2024 · Theaterhaus Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/25-scorpions.jpg", alt: "SCORPIONS", title: "SCORPIONS", date_location: "18.04.2023 · Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/26-eric-clapton.jpg", alt: "ERIC CLAPTON", title: "ERIC CLAPTON", date_location: "21.05.2022 · Liederhalle Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/27-zaz.jpg", alt: "ZAZ", title: "ZAZ", date_location: "29.06.2021 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/28-howard-carpendale.jpg", alt: "HOWARD CARPENDALE", title: "HOWARD CARPENDALE", date_location: "13.07.2020 · Porsche-Arena Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/29-kiss.jpg", alt: "KISS", title: "KISS", date_location: "24.08.2026 · SpardaWelt Freilichtbühne", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/30-iron-maiden.jpg", alt: "IRON MAIDEN", title: "IRON MAIDEN", date_location: "05.09.2025 · Kultur- und Kongresszentrum", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/31-moderat.jpg", alt: "MODERAT", title: "MODERAT", date_location: "17.10.2024 · Schlossplatz Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/32-stuttgart-live-festival.png", alt: "STUTTGART-LIVE FESTIVAL", title: "STUTTGART-LIVE FESTIVAL", date_location: "28.11.2023 · Theaterhaus Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/33-kontra-k.jpg", alt: "KONTRA K", title: "KONTRA K", date_location: "18.04.2022 · Stuttgart", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/34-volbeat.jpg", alt: "VOLBEAT", title: "VOLBEAT", date_location: "21.05.2021 · Liederhalle Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/35-stuttgart-live-festival.png", alt: "Stuttgart-live Festival", title: "Stuttgart-live Festival", date_location: "29.06.2020 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/36-wwe-live.jpg", alt: "WWE LIVE", title: "WWE LIVE", date_location: "13.07.2026 · Porsche-Arena Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/37-kultur-im-alten-schloss.jpg", alt: "Kultur IM ALTEN SCHLOSS", title: "Kultur IM ALTEN SCHLOSS", date_location: "24.08.2025 · SpardaWelt Freilichtbühne", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/38-live-sommer-autokonzerte-fuer-den-sueden.jpg", alt: "Live Sommer - Autokonzerte für den Süden", title: "Live Sommer - Autokonzerte für den Süden", date_location: "05.09.2024 · Kultur- und Kongresszentrum", partner: "Partner: Live Nation" }
  ].freeze

  HOME_EVENTS_PER_PAGE = 10
  STUTTGART_LIVE_SKS_HIGHLIGHTS_URL = "https://www.stuttgart-live.de/highlights?filter=sks".freeze

  JOBS = [
    {
      slug: "cateringhilfen",
      title: "Cateringhilfen",
      badge: "Minijob",
      meta_title: "Cateringhilfen | Jobs | Russ Live",
      meta_description: "Cateringhilfen auf Minijob-Basis bei Russ Live: Tätigkeitsfeld, Anforderungen und Ansprechpartner fuer Deine Bewerbung.",
      employment: "Zum nächstmöglichen Zeitpunkt, auf Minijob-Basis, m/w/d",
      area: "Catering",
      location: "Stuttgart",
      intro: "Du unterstützt unser Team hinter den Kulissen und sorgst dafür, dass Crew, Künstler*innen und Gäste zuverlässig versorgt werden.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Küchenteam bereitet frische Speisen zu",
      highlight_label: "Einzigartige Momente",
      highlight_title: "Arbeiten, wo Events entstehen.",
      highlight_text: "Vom ersten Aufbau bis zur letzten Show bist Du Teil eingespielter Teams und echter Live-Momente.",
      detail_id: "job-description",
      detail_label: "Jobdetails Cateringhilfen",
      responsibilities: [
        "Hilfstätigkeiten bei der Speisenzubereitung",
        "Auf- und Abbau von Buffets",
        "Unterstützung des Küchenteams"
      ],
      requirements: [
        "Zuverlässiges, gewissenhaftes Arbeiten",
        "Flexibilität auch spät abends oder nachts zu arbeiten",
        "Körperliche Fitness",
        "Team- und gute Kommunikationsfähigkeit",
        "Schnelle Auffassungsgabe",
        "Englischkenntnisse von Vorteil",
        "Motivation und Lust auf Arbeiten in der Event-Branche",
        "Gültiges allgemeines Gesundheitszeugnis"
      ]
    },
    {
      slug: "stagehands",
      title: "Stagehands",
      badge: "Minijob",
      meta_title: "Stagehands | Jobs | Russ Live",
      meta_description: "Stagehands auf Minijob-Basis bei Russ Live: Einsatzbereiche, Anforderungen und Bewerbung.",
      employment: "Flexible Einsätze bei Konzerten und Produktionen, m/w/d",
      area: "Auf-/Abbau",
      location: "Stuttgart",
      intro: "Du packst an, wenn Bühnen, Backstage-Bereiche und Produktionen aufgebaut, umgebaut und wieder abgebaut werden.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Team bei der Arbeit in einer Produktionsküche",
      highlight_label: "Teamwork in Bewegung",
      highlight_title: "Mitten in der Live-Produktion.",
      highlight_text: "Du bist dort, wo Technik, Timing und Teamarbeit zusammenspielen und jede Show vorbereitet wird.",
      detail_id: "job-description",
      detail_label: "Jobdetails Stagehands",
      responsibilities: [
        "Unterstützung beim Auf- und Abbau von Bühnen-, Licht- und Tontechnik",
        "Transport und Positionierung von Material im Venue",
        "Mithilfe bei Umbauten während laufender Produktionen"
      ],
      requirements: [
        "Körperliche Belastbarkeit und Freude an praktischer Arbeit",
        "Zuverlässigkeit und Pünktlichkeit bei wechselnden Einsatzzeiten",
        "Teamfähigkeit und respektvoller Umgang am Set",
        "Sicheres Arbeiten auch unter Zeitdruck",
        "Erste Erfahrung im Veranstaltungsbereich ist hilfreich, aber kein Muss"
      ]
    },
    {
      slug: "staplerfahrer-innen",
      title: "Staplerfahrer*innen",
      badge: "Minijob",
      meta_title: "Staplerfahrer*innen | Jobs | Russ Live",
      meta_description: "Staplerfahrer*innen fuer Eventproduktionen bei Russ Live: Aufgaben, Anforderungen und Bewerbung.",
      employment: "Flexible Einsätze auf Minijob-Basis, m/w/d",
      area: "Logistik",
      location: "Stuttgart",
      intro: "Du bewegst Material sicher über das Gelände und unterstützt unsere Teams bei logistischen Abläufen rund um Events.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Team bei der Arbeit in einer Produktionsküche",
      highlight_label: "Logistik mit Überblick",
      highlight_title: "Präzision hinter großen Shows.",
      highlight_text: "Mit ruhiger Hand und guter Abstimmung sorgst Du dafür, dass Material pünktlich am richtigen Ort ankommt.",
      detail_id: "job-description",
      detail_label: "Jobdetails Staplerfahrer*innen",
      responsibilities: [
        "Be- und Entladen von Veranstaltungs- und Produktionsequipment",
        "Sicherer Transport von Material auf dem Gelände",
        "Unterstützung der Lager- und Logistikteams vor Ort"
      ],
      requirements: [
        "Gültiger Staplerschein",
        "Verantwortungsbewusstes und umsichtiges Arbeiten",
        "Bereitschaft zu Einsätzen auch am Abend oder Wochenende",
        "Abstimmungssicherheit im Team und mit Gewerken vor Ort",
        "Erfahrung im Event- oder Logistikumfeld von Vorteil"
      ]
    },
    {
      slug: "securities",
      title: "Securities",
      badge: "Minijob",
      meta_title: "Securities | Jobs | Russ Live",
      meta_description: "Security-Jobs bei Russ Live: Einsatzorte, Anforderungen und Ansprechpartner fuer Deine Bewerbung.",
      employment: "Flexible Einsätze für Veranstaltungen, m/w/d",
      area: "Security",
      location: "Stuttgart",
      intro: "Du sorgst mit Übersicht, Ruhe und Präsenz für einen sicheren Ablauf bei Einlass, Besucherführung und Produktion.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Team bei der Arbeit in einer Produktionsküche",
      highlight_label: "Verantwortung vor Ort",
      highlight_title: "Sicherheit für besondere Abende.",
      highlight_text: "Du bist Ansprechpartner*in für Gäste und Teil eines Teams, das auch in dynamischen Situationen einen kühlen Kopf behält.",
      detail_id: "job-description",
      detail_label: "Jobdetails Securities",
      responsibilities: [
        "Unterstützung bei Einlass- und Kontrollsituationen",
        "Ansprechpartner*in für Besucher*innen und Teams vor Ort",
        "Mitwirkung an geordneten Abläufen in Publikums- und Backstagebereichen"
      ],
      requirements: [
        "Freundliches, souveränes Auftreten",
        "Zuverlässigkeit und Verantwortungsbewusstsein",
        "Kommunikationsstärke und Deeskalationsfähigkeit",
        "Bereitschaft zu Abend-, Wochenend- und Feiertagseinsätzen",
        "Unterrichtung oder Sachkunde nach Paragraph 34a ist von Vorteil"
      ]
    }
  ].freeze

  JOB_CONTACT = {
    name: "Sebastian Kränzlein",
    role: "Personaldisposition / Personalmarketing",
    phone_label: "Telefon +49.711.16 353 42",
    phone_href: "+497111635342",
    email: "sebastiankraenzlein@russ-live.de",
    image: "russ_live/team/sebastian-kraenzlein.jpg",
    image_alt: "Sebastian Kränzlein"
  }.freeze

  before_action :set_page_meta, except: :homepage_lane

  def home
    @home_references = HOME_REFERENCES
    @home_events_page = home_events_page
    @home_events = @home_events_page.events
    @home_events_next_cursor = @home_events_page.next_cursor
    @stuttgart_live_sks_highlights_url = STUTTGART_LIVE_SKS_HIGHLIGHTS_URL
  end

  def homepage_lane
    page = home_events_page(cursor: params[:cursor], per_page: params[:per_page])

    response.set_header("X-Homepage-Lane-Next-Cursor", page.next_cursor.to_s)
    response.set_header("X-Homepage-Lane-Has-More", page.next_cursor.present?.to_s)

    render partial: "pages/event_slider_cards", formats: [ :html ], locals: { events: page.events }
  rescue HomeEventsLanePager::InvalidCursor
    head :bad_request
  end
  def unternehmen; end
  def services; end
  def referenzen; end
  def jobs
    @jobs = JOBS
    @job_overview_hero_image = "russ_live/jobs/overview-hero.jpg"
    @job_contact = JOB_CONTACT
  end

  def job
    @jobs = JOBS
    @selected_job = find_job!(params[:slug])
    @job_contact = JOB_CONTACT
    @page_meta = PAGE_META.fetch(:job).merge(
      title: @selected_job[:meta_title],
      description: @selected_job[:meta_description]
    )
  end
  def kontakt; end
  def impressum; end
  def datenschutz; end
  def agb; end
  def jugendschutz; end

  private

  def find_job!(slug)
    JOBS.find { |job| job[:slug] == slug }.tap do |job|
      raise ActionController::RoutingError, "Not Found" if job.nil?
    end
  end

  def set_page_meta
    @page_key = action_name.to_sym
    @page_meta = PAGE_META.fetch(@page_key)
  end

  def home_events_page(cursor: nil, per_page: HOME_EVENTS_PER_PAGE)
    HomeEventsLanePager.new(
      relation: Event.homepage_sks_highlights,
      cursor: cursor,
      per_page: per_page.presence || HOME_EVENTS_PER_PAGE
    ).call
  end
end
