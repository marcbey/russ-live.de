class EventImage < SharedStuttgartRecord
  PURPOSE_SLIDER = "slider".freeze
  PURPOSE_DETAIL_HERO = "detail_hero".freeze

  self.table_name = "event_images"

  belongs_to :event
  has_one_attached :file

  scope :ordered, -> { order(created_at: :asc, id: :asc) }
  scope :slider, -> { where(purpose: PURPOSE_SLIDER) }
  scope :detail_hero, -> { where(purpose: PURPOSE_DETAIL_HERO) }
end
