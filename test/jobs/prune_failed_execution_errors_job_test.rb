require "test_helper"

class PruneFailedExecutionErrorsJobTest < ActiveJob::TestCase
  test "new failures keep their job reference without persisting error text" do
    with_failed_executions_table do
      failure = SolidQueue::FailedExecution.new(job_id: 1, created_at: Time.current)
      failure.exception = RuntimeError.new("Synthetic private message")
      failure.save!(validate: false)

      assert_nil failure.reload.read_attribute(:error)
      assert_equal({}, failure.error)
      assert_equal 1, failure.job_id
    end
  end

  test "expired error text is removed without discarding failed jobs" do
    with_failed_executions_table do
      SolidQueue::FailedExecution.insert_all!([
        { job_id: 1, created_at: 7.days.ago, error: { message: "old details" } },
        { job_id: 2, created_at: 1.day.ago, error: { message: "recent details" } }
      ])

      PruneFailedExecutionErrorsJob.perform_now

      assert_equal [ 1, 2 ], SolidQueue::FailedExecution.order(:job_id).pluck(:job_id)
      assert_nil SolidQueue::FailedExecution.find_by!(job_id: 1).read_attribute(:error)
      assert_equal "recent details", SolidQueue::FailedExecution.find_by!(job_id: 2).message
    end
  end

  private

  def with_failed_executions_table
    SolidQueue::FailedExecution.with_connection do |connection|
      connection.execute(<<~SQL)
        CREATE TEMP TABLE solid_queue_failed_executions (
          id bigserial PRIMARY KEY, job_id bigint NOT NULL, created_at timestamp NOT NULL, error text
        )
      SQL
      SolidQueue::FailedExecution.reset_column_information
      yield
    ensure
      connection.execute("DROP TABLE IF EXISTS pg_temp.solid_queue_failed_executions")
      SolidQueue::FailedExecution.reset_column_information
    end
  end
end
