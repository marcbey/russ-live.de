class Event < SharedStuttgartRecord
  self.table_name = "events"

  belongs_to :venue_record, class_name: "Venue", foreign_key: :venue_id, optional: true, inverse_of: :events
  has_many :event_images
  has_one_attached :promotion_banner_image

  scope :chronological, -> { order(start_at: :asc, id: :asc) }
  scope :published_live, lambda {
    where(status: "published")
      .where("published_at IS NULL OR published_at <= ?", Time.current)
      .chronological
  }
end
