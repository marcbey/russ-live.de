Rails.application.config.to_prepare do
  SolidQueue::FailedExecution.prepend(SolidQueueErrorPrivacy)
end
