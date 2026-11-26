class PruneFailedExecutionErrorsJob < ApplicationJob
  queue_as :default

  def perform
    # Preserve the failed job and its retry state.
    SolidQueue::FailedExecution.where(created_at: ..144.hours.ago)
      .where.not(error: nil).in_batches.update_all(error: nil)
  end
end
