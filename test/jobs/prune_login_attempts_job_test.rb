require "test_helper"

class PruneLoginAttemptsJobTest < ActiveJob::TestCase
  test "removes old login logs and preserves recent attempts even when run again" do
    travel_to Time.utc(2026, 11, 26, 12) do
      expired = LoginAttempt.create!(outcome: "failed", created_at: 7.days.ago)
      at_cutoff = LoginAttempt.create!(outcome: "successful", created_at: 144.hours.ago)
      recent = LoginAttempt.create!(outcome: "failed", created_at: 144.hours.ago + 1.second)

      2.times { PruneLoginAttemptsJob.perform_now }

      assert_not LoginAttempt.exists?(expired.id)
      assert_not LoginAttempt.exists?(at_cutoff.id)
      assert LoginAttempt.exists?(recent.id)
    end
  end
end
