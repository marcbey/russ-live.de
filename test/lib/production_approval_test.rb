require "test_helper"
require "open3"
require_relative "../../script/ops/production_approval"

class ProductionApprovalTest < ActiveSupport::TestCase
  REPOSITORY = "marcbey/stuttgart-live.de".freeze

  def stage(id = 42, updated_at = "2026-10-18T01:00:00Z")
    { "id" => id, "event" => "workflow_run", "status" => "completed", "conclusion" => "success",
      "path" => ".github/workflows/deploy-staging.yml", "head_branch" => "main", "updated_at" => updated_at,
      "repository" => { "full_name" => REPOSITORY, "id" => 1 }, "head_repository" => { "full_name" => REPOSITORY, "id" => 1 } }
  end

  def manifest
    { "staging_run_id" => 42, "image" => "ghcr.io/marcbey/stuttgart-live-de", "commit" => "a" * 40, "digest" => "sha256:#{'b' * 64}" }
  end

  def api_for(responses)
    Object.new.tap do |api|
      api.define_singleton_method(:github_json) { |path| responses.fetch(path).deep_dup }
    end
  end

  test "automatic approval selects the completed staging run rather than the workflow definition commit" do
    script = Rails.root.join("script/ops/production_approval.rb").to_s
    code = <<~'RUBY'
      require ARGV.shift
      event = { 'repository' => { 'full_name' => 'marcbey/stuttgart-live.de' },
        'workflow_run' => { 'id' => 42, 'head_sha' => 'a' * 40 } }
      selected = Ops::ProductionApproval.selection(repository: 'marcbey/stuttgart-live.de', event_name: 'workflow_run', ref: 'refs/heads/main', event: event)
      abort 'wrong source' unless selected == { staging_run_id: 42, mode: 'promote' }
    RUBY
    output, error, status = Open3.capture3("mise", "exec", "--", "ruby", "-e", code, script)
    assert status.success?, output + error
  end

  test "dispatch rollback requires an explicit source and own main while unknown modes fail" do
    event = { "repository" => { "full_name" => REPOSITORY }, "inputs" => { "mode" => "rollback", "staging_run_id" => "12" } }
    assert_equal({ staging_run_id: 12, mode: "rollback" }, Ops::ProductionApproval.selection(repository: REPOSITORY, event_name: "workflow_dispatch", ref: "refs/heads/main", event:))
    [ [ "refs/heads/feature", event ], [ "refs/heads/main", event.deep_merge("inputs" => { "mode" => "anything" }) ],
      [ "refs/heads/main", event.deep_merge("inputs" => { "staging_run_id" => "" }) ],
      [ "refs/heads/main", event.deep_merge("repository" => { "full_name" => "fork/project" }) ] ].each do |ref, payload|
      assert_raises(Ops::ReleaseSupport::Error) { Ops::ProductionApproval.selection(repository: REPOSITORY, event_name: "workflow_dispatch", ref:, event: payload) }
    end
  end

  test "missing or bypassable production review gates prevent preparing a deployment" do
    environment = { "can_admins_bypass" => false, "protection_rules" => [ { "type" => "required_reviewers", "prevent_self_review" => false,
      "reviewers" => [ { "type" => "User", "reviewer" => { "id" => 3525 } }, { "type" => "User", "reviewer" => { "id" => 266476119 } } ] } ] }
    responses = { "repos/#{REPOSITORY}/environments/production" => environment }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api: api_for(responses))
    assert_nothing_raised { approval.validate_environment! }
    environment["can_admins_bypass"] = true
    assert_raises(Ops::ReleaseSupport::Error) { approval.validate_environment! }
    environment["can_admins_bypass"] = false
    environment["protection_rules"].clear
    assert_raises(Ops::ReleaseSupport::Error) { approval.validate_environment! }
  end

  test "normal promotion needs the newest completed staging proof and identical running image" do
    path = "repos/#{REPOSITORY}/actions/workflows/deploy-staging.yml/runs?branch=main&status=success&per_page=100&page=1"
    responses = { path => { "workflow_runs" => [ stage, stage(41, "2026-10-18T00:00:00Z") ] } }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api: api_for(responses))
    remote = Object.new
    identity = manifest.slice("image", "commit", "digest")
    remote.define_singleton_method(:running) { |**| identity }
    assert_nothing_raised { approval.validate_current!(manifest:, remote:, project: "stuttgart_live_de", mode: "promote") }
    identity["digest"] = "sha256:#{'c' * 64}"
    assert_raises(Ops::ReleaseSupport::Error) { approval.validate_current!(manifest:, remote:, project: "stuttgart_live_de", mode: "promote") }
    identity["digest"] = manifest.fetch("digest")
    responses[path]["workflow_runs"] << stage(43, "2026-10-18T02:00:00Z")
    assert_raises(Ops::ReleaseSupport::Error) { approval.validate_current!(manifest:, remote:, project: "stuttgart_live_de", mode: "promote") }
    assert_nothing_raised { approval.validate_current!(manifest:, remote:, project: "stuttgart_live_de", mode: "rollback") }
  end

  test "newest staging is determined by successful completion including delayed runs and reruns" do
    path = "repos/#{REPOSITORY}/actions/workflows/deploy-staging.yml/runs?branch=main&status=success&per_page=100&page=1"
    runs = [ stage(43), stage(42, "2026-10-18T02:00:00Z"), stage(99, "2026-10-18T03:00:00Z").merge("head_repository" => { "full_name" => "fork/repo" }) ]
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api: api_for(path => { "workflow_runs" => runs }))
    assert_nothing_raised { assert_equal 42, approval.latest_staging_run.fetch("id") }
  end

  test "supersession cancels only older automatic approvals still waiting for production" do
    waiting = stage(10).merge("status" => "waiting", "conclusion" => nil, "path" => ".github/workflows/deploy-production.yml")
    rollback = waiting.merge("id" => 11, "event" => "workflow_dispatch")
    running = waiting.merge("id" => 12, "status" => "in_progress")
    states = { 10 => waiting, 11 => rollback, 12 => running }
    api = Object.new
    api.define_singleton_method(:github_json) do |path|
      if path.include?("/workflows/")
        { "workflow_runs" => states.values.deep_dup }
      else
        [ { "environment" => { "name" => "production" } } ]
      end
    end
    api.define_singleton_method(:run) { |_, id| states.fetch(id).deep_dup }
    api.define_singleton_method(:capture) do |*arguments|
      id = arguments.last.split("/")[-2].to_i
      states.fetch(id).merge!("status" => "completed", "conclusion" => "cancelled")
      ""
    end
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api:, sleeper: ->(_) { })
    assert_nothing_raised { approval.supersede_waiting!(current_run_id: 20) }
    assert_equal "cancelled", states.fetch(10).fetch("conclusion")
    assert_equal "waiting", states.fetch(11).fetch("status")
    assert_equal "in_progress", states.fetch(12).fetch("status")
  end

  test "summary compares all unreleased changes against the actual production commit" do
    responses = {
      "repos/#{REPOSITORY}/compare/#{'d' * 40}...#{'a' * 40}?per_page=100&page=1" => { "commits" => [ { "sha" => "e" * 40 }, { "sha" => "a" * 40 } ] },
      "repos/#{REPOSITORY}/commits/#{'e' * 40}/pulls?per_page=100" => [ { "number" => 7, "title" => "Earlier feature" } ],
      "repos/#{REPOSITORY}/commits/#{'a' * 40}/pulls?per_page=100" => [ { "number" => 8, "title" => "Later <feature> [unsafe](https://attacker.example)\n# Heading" } ]
    }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api: api_for(responses))
    summary = nil
    assert_nothing_raised { summary = approval.summary(manifest:, production: { "commit" => "d" * 40 }, mode: "promote") }
    assert_includes summary, "/compare/#{'d' * 40}..#{'a' * 40}"
    assert_includes summary, "/pull/7"
    assert_includes summary, "/pull/8"
    assert_includes summary, "Later &lt;feature&gt;"
    assert_includes summary, '\[unsafe\]\(https://attacker\.example\) \# Heading'
    assert_includes summary, "/actions/runs/42"
  end

  test "rollback summary lists removed pull requests even when target is an ancestor" do
    responses = {
      "repos/#{REPOSITORY}/compare/#{'d' * 40}...#{'a' * 40}?per_page=100&page=1" => { "commits" => [] },
      "repos/#{REPOSITORY}/compare/#{'a' * 40}...#{'d' * 40}?per_page=100&page=1" => { "commits" => [ { "sha" => "e" * 40 } ] },
      "repos/#{REPOSITORY}/commits/#{'e' * 40}/pulls?per_page=100" => [ { "number" => 7, "title" => "Feature removed by rollback" } ]
    }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api: api_for(responses))
    summary = approval.summary(manifest:, production: { "commit" => "d" * 40 }, mode: "rollback")
    assert_includes summary, "Entfallende Pull Requests"
    assert_includes summary, "/pull/7"
    assert_includes summary, "/compare/#{'d' * 40}..#{'a' * 40}"
  end

  test "approval binding rejects changed peer evidence even when the reviewed image is unchanged" do
    reviewed = manifest.merge("compatible_peers" => [ { "commit" => "c" * 40 } ])
    fingerprint = Digest::SHA256.hexdigest(JSON.generate(Ops::ImageFingerprint.canonical(reviewed)))
    arguments = { commit: reviewed.fetch("commit"), digest: reviewed.fetch("digest"), fingerprint: }
    assert_nothing_raised { Ops::ProductionApproval.validate_binding!(manifest: reviewed.deep_dup, **arguments) }
    reviewed["compatible_peers"].first["commit"] = "d" * 40
    assert_raises(Ops::ReleaseSupport::Error) { Ops::ProductionApproval.validate_binding!(manifest: reviewed, **arguments) }
  end

  test "an older delayed preparation cannot cancel a newer pending production approval" do
    candidate = stage(30).merge("status" => "waiting", "path" => ".github/workflows/deploy-production.yml")
    responses = {
      "repos/#{REPOSITORY}/actions/workflows/deploy-production.yml/runs?event=workflow_run&status=waiting&per_page=100&page=1" => { "workflow_runs" => [ candidate ] },
      "repos/#{REPOSITORY}/actions/runs/30/pending_deployments" => [ { "environment" => { "name" => "production" } } ]
    }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api: api_for(responses))
    assert_raises(Ops::ProductionApproval::Superseded) { approval.supersede_waiting!(current_run_id: 20) }
  end

  test "an approved job observed in progress is never selected for supersession" do
    candidate = stage(10).merge("status" => "waiting", "path" => ".github/workflows/deploy-production.yml")
    responses = {
      "repos/#{REPOSITORY}/actions/workflows/deploy-production.yml/runs?event=workflow_run&status=waiting&per_page=100&page=1" => { "workflow_runs" => [ candidate ] },
      "repos/#{REPOSITORY}/actions/runs/10/pending_deployments" => [ { "environment" => { "name" => "production" } } ]
    }
    api = api_for(responses)
    api.define_singleton_method(:run) { |*| candidate.merge("status" => "in_progress") }
    api.define_singleton_method(:capture) { |*| raise "Running deployment was cancelled" }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api:)
    assert_nothing_raised { approval.supersede_waiting!(current_run_id: 20) }
  end

  test "approval racing the final waiting read must finish cancellation before returning" do
    candidate = stage(10).merge("status" => "waiting", "path" => ".github/workflows/deploy-production.yml")
    responses = {
      "repos/#{REPOSITORY}/actions/workflows/deploy-production.yml/runs?event=workflow_run&status=waiting&per_page=100&page=1" => { "workflow_runs" => [ candidate.deep_dup ] },
      "repos/#{REPOSITORY}/actions/runs/10/pending_deployments" => [ { "environment" => { "name" => "production" } } ]
    }
    api = api_for(responses)
    api.define_singleton_method(:run) { |*| candidate.deep_dup }
    api.define_singleton_method(:capture) { |*| candidate["status"] = "in_progress" }
    waits = 0
    sleeper = ->(_) { waits += 1; candidate["status"] = "completed" }
    approval = Ops::ProductionApproval.new(repository: REPOSITORY, api:, sleeper:)
    approval.supersede_waiting!(current_run_id: 20)
    assert_equal "completed", candidate["status"]
    assert_equal 1, waits
  end
end
