require "test_helper"
require "time"
require_relative "../../script/ops/release_manifest"

class ReleaseManifestTest < ActiveSupport::TestCase
  def evidence
    repository = "marcbey/russ-live.de"
    commit = "a" * 40
    digest = "sha256:#{'b' * 64}"
    manifest = { "schema_version" => 1, "repository" => repository, "commit" => commit, "image" => "ghcr.io/marcbey/russ-live-de",
      "digest" => digest, "ci_run_id" => 11, "staging_run_id" => 22, "deployment_config_sha256" => "c" * 64,
      "paired_app_commit" => "d" * 40, "compatible_peer_commits" => [ "d" * 40, "e" * 40 ] }
    base = { "status" => "completed", "conclusion" => "success", "head_branch" => "main", "head_sha" => commit,
      "repository" => { "full_name" => repository, "id" => 1 }, "head_repository" => { "full_name" => repository, "id" => 1 } }
    ci = base.merge("id" => 11, "event" => "push", "path" => ".github/workflows/ci.yml")
    stage = base.merge("id" => 22, "event" => "workflow_run", "path" => ".github/workflows/deploy-staging.yml",
      "artifact" => { "id" => 33, "name" => "staging-release", "expired" => false, "expires_at" => (Time.now.utc + 3600).iso8601,
        "workflow_run" => { "id" => 22, "head_branch" => "main", "head_repository_id" => 1, "repository_id" => 1 } })
    { manifest:, expected_repository: repository, ci_run: ci, staging_run: stage, registry_digest: digest, peer_production_commit: "e" * 40 }
  end

  test "an older specifically tested commit and compatible production peer are valid" do
    data = evidence
    # workflow_run's own head_sha identifies its workflow definition on default branch.
    data[:staging_run]["head_sha"] = "f" * 40
    assert Ops::ReleaseManifest.validate!(**data)
  end

  test "forged failed fork pull-request incomplete or expired evidence never authorizes deploy" do
    mutations = [
      ->(d) { d[:manifest]["repository"] = "other/project" },
      ->(d) { d[:ci_run]["conclusion"] = "failure" },
      ->(d) { d[:ci_run]["event"] = "pull_request" },
      ->(d) { d[:ci_run]["head_branch"] = "feature" },
      ->(d) { d[:ci_run]["head_repository"]["full_name"] = "fork/project" },
      ->(d) { d[:ci_run]["head_sha"] = "f" * 40 },
      ->(d) { d[:registry_digest] = "sha256:#{'f' * 64}" },
      ->(d) { d[:staging_run]["conclusion"] = "failure" },
      ->(d) { d[:staging_run]["status"] = "in_progress" },
      ->(d) { d[:staging_run]["path"] = ".github/workflows/other.yml" },
      ->(d) { d[:staging_run].delete("artifact") },
      ->(d) { d[:staging_run]["artifact"]["expired"] = true },
      ->(d) { d[:staging_run]["artifact"]["expires_at"] = (Time.now.utc - 1).iso8601 },
      ->(d) { d[:staging_run]["artifact"]["workflow_run"]["id"] = 23 },
      ->(d) { d[:staging_run]["artifact"]["workflow_run"]["head_repository_id"] = 2 },
      ->(d) { d[:peer_production_commit] = "f" * 40 },
      ->(d) { d[:manifest]["compatible_peer_commits"] = [] },
      ->(d) { d[:manifest]["image"] = "ghcr.io/other/project" },
      ->(d) { d[:manifest]["commit"] = "main; echo unsafe" }
    ]
    mutations.each_with_index do |mutate, index|
      data = evidence
      mutate.call(data)
      assert_raises(Ops::ReleaseManifest::Error, "mutation #{index}") { Ops::ReleaseManifest.validate!(**data) }
    end
  end

  test "deployment config hash includes actual versioned bytes and paths" do
    first = Ops::ReleaseManifest.deployment_config_sha256(root: Rails.root)
    assert_match(/\A[a-f0-9]{64}\z/, first)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      File.write(File.join(root, "config/deploy.yml"), "image: one\n")
      before = Ops::ReleaseManifest.deployment_config_sha256(root:)
      File.write(File.join(root, "config/deploy.yml"), "image: two\n")
      assert_not_equal before, Ops::ReleaseManifest.deployment_config_sha256(root:)
    end
  end
end
