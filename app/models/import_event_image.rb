class ImportEventImage < SharedStuttgartRecord
  self.table_name = "import_event_images"

  belongs_to :event, foreign_key: :import_event_id, optional: true, inverse_of: :import_event_images

  scope :for_events, -> { where(import_class: "Event") }
  scope :ordered, -> { order(:position, :id) }
end
