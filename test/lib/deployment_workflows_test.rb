require "test_helper"
require "yaml"

class DeploymentWorkflowsTest < ActiveSupport::TestCase
  def workflow(name)
    YAML.safe_load_file(Rails.root.join(".github/workflows/#{name}.yml"), aliases: true)
  end

  test "production only promotes a selected staging run and cannot rebuild or reboot the shared proxy" do
    prod = workflow("deploy-production")
    trigger = prod["on"] || prod[true]
    assert_equal [ "workflow_dispatch" ], trigger.keys
    assert trigger.dig("workflow_dispatch", "inputs", "staging_run_id", "required")
    steps = prod.fetch("jobs").fetch("deploy").fetch("steps")
    assert_not steps.any? { |step| step["uses"].to_s.start_with?("docker/build-push-action") }
    text = steps.to_json
    assert_not_includes text, "proxy reboot"
    assert_not_includes text, ":latest"
    assert_includes text, "promote_release.rb"
  end

  test "stage checks the successful own main push before loading its prefixed secrets" do
    stage = workflow("deploy-staging")
    trigger = stage["on"] || stage[true]
    assert_equal [ "workflow_run" ], trigger.keys
    assert_equal [ "completed" ], trigger.dig("workflow_run", "types")
    job = stage.fetch("jobs").fetch("deploy")
    assert_equal "staging", job["environment"]
    assert_includes job["if"], "head_repository.full_name == github.repository"
    assert_includes job["if"], "conclusion == 'success'"
    steps = job.fetch("steps")
    build = steps.index { |step| step["uses"].to_s.start_with?("docker/build-push-action") }
    runtime = steps.index { |step| step["run"].to_s.include?("nginx_runtime_check.rb") }
    deploy = steps.index { |step| step["run"].to_s.include?("stage_release.rb") }
    assert build < runtime && runtime < deploy
    secret_names = steps.to_json.scan(/secrets\.([A-Z_]+)/).flatten
    assert secret_names.all? { |name| name.start_with?("STAGING_") }, secret_names.inspect
    assert_includes steps.to_json, "workflow_run.head_sha"
  end

  test "pull requests and main share complete mise CI" do
    ci = workflow("ci")
    triggers = ci["on"] || ci[true]
    assert triggers.key?("pull_request")
    assert_equal [ "main" ], triggers.dig("push", "branches")
    assert_includes ci.to_json, "mise exec -- bin/ci"
  end
end
