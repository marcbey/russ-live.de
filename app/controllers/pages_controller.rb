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
    @jobs = Job.published.with_contact_and_image.ordered.to_a
    @job_categories = Job.categories_from(@jobs)
    @job_overview_hero_image = "russ_live/jobs/overview-hero.jpg"
  end

  def job
    @jobs = Job.published.with_contact_and_image.ordered.to_a
    @selected_job = find_job!(params[:slug])
    @page_meta = PAGE_META.fetch(:job).merge(
      title: @selected_job.meta_title.presence || "#{@selected_job.title} | Jobs | Russ Live",
      description: @selected_job.meta_description.presence || PAGE_META.fetch(:job).fetch(:description)
    )
  end
  def kontakt; end
  def impressum; end
  def datenschutz; end
  def agb; end
  def jugendschutz; end

  private

  def find_job!(slug)
    Job.published.with_contact_and_image.find_by(slug: slug).tap do |job|
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
