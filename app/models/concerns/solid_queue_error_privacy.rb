module SolidQueueErrorPrivacy
  extend ActiveSupport::Concern

  prepended do
    before_save :remove_error_details
  end

  def error
    self[:error] || {}
  end

  private

  def remove_error_details
    self.error = nil
  end
end
