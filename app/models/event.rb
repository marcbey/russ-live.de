class Event < SharedStuttgartRecord
  self.table_name = "events"

  belongs_to :venue_record, class_name: "Venue", foreign_key: :venue_id, optional: true, inverse_of: :events
  has_many :event_images
  has_many :event_offers
  has_many :import_event_images, -> { for_events.ordered }, foreign_key: :import_event_id, inverse_of: :event
  has_one_attached :promotion_banner_image
  has_rich_text :press_text

  STUTTGART_LIVE_EVENT_BASE_URL = "https://www.stuttgart-live.de/events/".freeze

  scope :chronological, -> { order(start_at: :asc, id: :asc) }
  scope :published_live, lambda {
    where(status: "published")
      .where("published_at IS NULL OR published_at <= ?", Time.current)
      .chronological
  }
  scope :published_on_russ_live, -> { published_live.where(publish_on_russ_live: true) }
  scope :upcoming, -> { where("start_at >= ?", Time.zone.today.beginning_of_day) }
  scope :sks_promoters, lambda {
    sks_promoter_ids = AppSetting.sks_promoter_ids
    sks_promoter_ids.any? ? where(promoter_id: sks_promoter_ids).or(where(promoter_name: sks_promoter_ids)) : none
  }
  scope :homepage_sks_highlights, lambda {
    published_live
      .upcoming
      .sks_promoters
      .includes(:venue_record, :event_offers, :import_event_images, event_images: [ file_attachment: :blob ])
      .reorder(:start_at, :id)
  }

  def venue
    venue_record&.name.to_s.presence
  end

  def event_image
    if association(:event_images).loaded?
      ordered_images = event_images.sort_by { |image| [ image.created_at || Time.zone.at(0), image.id.to_i ] }
      return ordered_images.find(&:detail_hero?) || ordered_images.first
    end

    event_images.detail_hero.ordered.first || event_images.ordered.first
  end

  def home_slider_image
    image = event_image
    return image if image.present? && image.file.attached?

    import_event_image
  end

  def import_event_image
    if association(:import_event_images).loaded?
      import_event_images.first
    else
      import_event_images.first
    end
  end

  def public_ticket_offer
    if association(:event_offers).loaded?
      return event_offers
        .select(&:public_ticket_active?)
        .min_by { |offer| [ offer.priority_rank.to_i, offer.id.to_i ] }
    end

    event_offers.active_ticket.ordered.first
  end

  def public_ticket_status_offer
    if association(:event_offers).loaded?
      return event_offers.min_by { |offer| [ offer.priority_rank.to_i, offer.id.to_i ] }
    end

    event_offers.ordered.first
  end

  def public_ticket_status_label
    offer = public_ticket_status_offer
    return "Abgesagt" if offer&.canceled?

    "Ausverkauft" if offer&.sold_out?
  end

  def public_ticket_url
    public_ticket_offer&.resolved_ticket_url.presence || "#{STUTTGART_LIVE_EVENT_BASE_URL}#{slug}"
  end
end
