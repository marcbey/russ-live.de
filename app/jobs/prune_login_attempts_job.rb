class PruneLoginAttemptsJob < ApplicationJob
  queue_as :default

  def perform
    # Leave a full day for scheduling delays before the seven-day deadline.
    LoginAttempt.where(created_at: ..144.hours.ago).in_batches.delete_all
  end
end
