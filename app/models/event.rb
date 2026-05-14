class Event < SharedStuttgartRecord
  self.table_name = "events"

  belongs_to :venue_record, class_name: "Venue", foreign_key: :venue_id, optional: true, inverse_of: :events
  has_many :event_images
  has_many :event_offers
  has_one_attached :promotion_banner_image
  has_rich_text :press_text

  scope :chronological, -> { order(start_at: :asc, id: :asc) }
  scope :published_live, lambda {
    where(status: "published")
      .where("published_at IS NULL OR published_at <= ?", Time.current)
      .chronological
  }
  scope :published_on_russ_live, -> { published_live.where(publish_on_russ_live: true) }

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

  def public_ticket_offer
    if association(:event_offers).loaded?
      return event_offers
        .select(&:active_ticket?)
        .min_by { |offer| [ offer.priority_rank.to_i, offer.id.to_i ] }
    end

    event_offers.active_ticket.ordered.first
  end
end
