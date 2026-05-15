require_dependency Rails.root.join("app/services/home_events_lane_pager").to_s

class PagesController < ApplicationController
  allow_unauthenticated_access

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
    @home_references = Reference.published.with_image.ordered.to_a.select { |reference| reference.reference_image&.image? }
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
  def referenzen
    @references = Reference.published.with_image.ordered.to_a
    @reference_tags = Reference.tags_from(@references)
  end
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
