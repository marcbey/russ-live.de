require "test_helper"
require "yaml"

class DeploymentWorkflowsTest < ActiveSupport::TestCase
  def workflow(name)
    YAML.safe_load_file(Rails.root.join(".github/workflows/#{name}.yml"), aliases: true)
  end

  test "production automatically prepares successful staging and offers explicit main-only rollback" do
    prod = workflow("deploy-production")
    trigger = prod["on"] || prod[true]
    assert_equal [ "workflow_dispatch", "workflow_run" ], trigger.keys.sort
    assert_equal [ "Deploy Staging" ], trigger.dig("workflow_run", "workflows")
    assert_equal [ "completed" ], trigger.dig("workflow_run", "types")
    assert_equal [ "main" ], trigger.dig("workflow_run", "branches")
    inputs = trigger.dig("workflow_dispatch", "inputs")
    assert inputs.dig("staging_run_id", "required")
    assert_equal "string", inputs.dig("staging_run_id", "type")
    assert_equal "choice", inputs.dig("mode", "type")
    assert inputs.dig("mode", "required")
    assert_equal "rollback", inputs.dig("mode", "default")
    assert_equal [ "rollback", "promote" ], inputs.dig("mode", "options")

    prepare = prod.fetch("jobs")["prepare"]
    assert prepare, "production must validate the trigger before requesting approval"
    condition = prepare.fetch("if")
    assert_includes condition, "github.event_name == 'workflow_run'"
    assert_includes condition, "workflow_run.conclusion == 'success'"
    assert_includes condition, "workflow_run.head_branch == 'main'"
    assert_includes condition, "workflow_run.head_repository.full_name == github.repository"
    assert_includes condition, "github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'"
  end

  test "production preparation uses only staging credentials and exports the validated release identity" do
    prod = workflow("deploy-production")
    assert_not prod.key?("concurrency"), "an approval must not hold the staging deployment queue"
    prepare = prod.fetch("jobs")["prepare"]
    assert prepare, "production must prepare without production credentials"
    assert_equal({ "name" => "staging", "deployment" => false }, prepare["environment"])
    assert_equal({ "contents" => "read", "actions" => "write", "packages" => "read" }, prepare["permissions"])
    secret_names = prepare.to_json.scan(/secrets\.([A-Z_]+)/).flatten
    assert_equal [ "STAGING_SSH_PRIVATE_KEY" ], secret_names.uniq
    checkout = prepare.fetch("steps").find { |step| step["uses"].to_s.start_with?("actions/checkout@") }
    assert_equal "main", checkout.dig("with", "ref")
    assert_equal "release-control", checkout.dig("with", "path")
    assert_equal false, checkout.dig("with", "persist-credentials")
    assert_equal "release-control", prepare.dig("defaults", "run", "working-directory")
    release = script_step(prepare, "prepare_production")
    assert release, "the trusted helper must validate and summarize the release"
    assert_equal "release", release["id"]
    assert_equal "${{ github.token }}", prepare.dig("env", "GH_TOKEN")
    assert_not_includes release.fetch("run"), "${{", "event inputs must be parsed from GITHUB_EVENT_PATH"
    assert_equal({
      "commit" => "${{ steps.release.outputs.commit }}",
      "digest" => "${{ steps.release.outputs.digest }}",
      "manifest_sha256" => "${{ steps.release.outputs.manifest_sha256 }}",
      "production_sha256" => "${{ steps.release.outputs.production_sha256 }}",
      "staging_run_id" => "${{ steps.release.outputs.staging_run_id }}",
      "mode" => "${{ steps.release.outputs.mode }}",
      "control_commit" => "${{ steps.release.outputs.control_commit }}"
    }, prepare["outputs"])
  end

  test "production approval binds the candidate and uses the pinned trusted promotion policy" do
    prod = workflow("deploy-production")
    deploy = prod.fetch("jobs").fetch("deploy")
    assert_equal "prepare", deploy["needs"]
    assert_equal "production", deploy["environment"]
    assert_includes deploy.fetch("name"), "needs.prepare.outputs.mode"
    assert_includes deploy.fetch("name"), "needs.prepare.outputs.commit"
    assert_equal({ "contents" => "read", "actions" => "read", "packages" => "read" }, deploy["permissions"])
    assert_equal "release-control", deploy.dig("defaults", "run", "working-directory")

    checkouts = deploy.fetch("steps").select { |step| step["uses"].to_s.start_with?("actions/checkout@") }
    assert_equal 2, checkouts.size
    controls = checkouts.find { |step| step.dig("with", "path") == "release-control" }
    candidate = checkouts.find { |step| step.dig("with", "path") == "release-candidate" }
    assert_equal "${{ needs.prepare.outputs.control_commit }}", controls.dig("with", "ref")
    assert_equal "${{ needs.prepare.outputs.commit }}", candidate.dig("with", "ref")
    assert checkouts.all? { |step| step.dig("with", "persist-credentials") == false }
    mise = deploy.fetch("steps").find { |step| step["uses"].to_s.start_with?("jdx/mise-action@") }
    assert_equal "release-control", mise.dig("with", "working_directory")
    install = deploy.fetch("steps").find { |step| step["run"].to_s.include?("bundle install") }
    assert install, "dependencies must come from the trusted controls checkout"
    assert_equal "release-control", install.fetch("working-directory", deploy.dig("defaults", "run", "working-directory"))

    promotion = script_step(deploy, "promote_release")
    assert promotion, "the gated job must promote the validated image"
    assert_equal "release-control", promotion.fetch("working-directory", deploy.dig("defaults", "run", "working-directory"))
    assert_equal "${{ github.workspace }}/release-candidate", promotion.dig("env", "RELEASE_CHECKOUT")
    assert_equal "${{ needs.prepare.outputs.staging_run_id }}", promotion.dig("env", "RELEASE_STAGING_RUN_ID")
    assert_equal "${{ needs.prepare.outputs.commit }}", promotion.dig("env", "RELEASE_EXPECTED_COMMIT")
    assert_equal "${{ needs.prepare.outputs.digest }}", promotion.dig("env", "RELEASE_EXPECTED_DIGEST")
    assert_equal "${{ needs.prepare.outputs.manifest_sha256 }}", promotion.dig("env", "RELEASE_EXPECTED_MANIFEST_SHA256")
    assert_equal "${{ needs.prepare.outputs.production_sha256 }}", promotion.dig("env", "RELEASE_EXPECTED_PRODUCTION_SHA256")
    assert_equal "${{ needs.prepare.outputs.mode }}", promotion.dig("env", "RELEASE_MODE")
  end

  test "production promotes without rebuilding replacing image tags or rebooting the shared proxy" do
    prod = workflow("deploy-production")
    steps = prod.fetch("jobs").values.flat_map { |job| job.fetch("steps") }
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

  test "staging serializes only its own runs without cancelling an active deployment" do
    stage = workflow("deploy-staging")
    assert_equal "live-staging-${{ github.repository }}", stage.dig("concurrency", "group")
    assert_equal false, stage.dig("concurrency", "cancel-in-progress")
  end

  test "pull requests and main share complete mise CI" do
    ci = workflow("ci")
    triggers = ci["on"] || ci[true]
    assert triggers.key?("pull_request")
    assert_equal [ "main" ], triggers.dig("push", "branches")
    assert_includes ci.to_json, "mise exec -- bin/ci"
  end

  private

  def script_step(job, script)
    job.fetch("steps").find { |step| step["run"].to_s.include?("script/ops/#{script}.rb") }
  end
end
