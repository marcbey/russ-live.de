class RussRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :russ }
end
