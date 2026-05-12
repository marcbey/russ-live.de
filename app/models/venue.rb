class Venue < SharedStuttgartRecord
  self.table_name = "venues"

  has_many :events, foreign_key: :venue_id, inverse_of: :venue_record
end
