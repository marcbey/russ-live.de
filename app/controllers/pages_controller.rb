require_dependency Rails.root.join("app/services/home_events_lane_pager").to_s

class PagesController < ApplicationController
  allow_unauthenticated_access

  PAGE_META = {
    home: { body_class: "home-body" },
    unternehmen: {},
    services: { body_class: "services-body" },
    referenzen: { body_class: "references-body" },
    jobs: { body_class: "jobs-body jobs-overview-body" },
    job: { body_class: "jobs-body job-detail-page-body" },
    kontakt: {},
    impressum: {},
    datenschutz: {},
    agb: {},
    jugendschutz: {}
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
    @job_overview_hero_image = "russ_live/jobs/overview-hero.jpg"
    @page_meta = PAGE_META.fetch(:job).merge(
      title: @selected_job.meta_title.presence || t("pages.job.meta.dynamic_title", title: @selected_job.title),
      description: @selected_job.meta_description.presence || t("pages.job.meta.description")
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
    @page_meta = PAGE_META.fetch(@page_key).merge(
      title: t("pages.#{@page_key}.meta.title"),
      description: t("pages.#{@page_key}.meta.description")
    )
  end

  def home_events_page(cursor: nil, per_page: HOME_EVENTS_PER_PAGE)
    HomeEventsLanePager.new(
      relation: Event.homepage_sks_highlights,
      cursor: cursor,
      per_page: per_page.presence || HOME_EVENTS_PER_PAGE
    ).call
  end
end
