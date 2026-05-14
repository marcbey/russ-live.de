class SharedStuttgartRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :primary, reading: :primary }

  def readonly?
    true
  end
end
