require_relative "deploy_release"
require_relative "compatibility_probe"

begin
  deployment = Ops::ReleaseDeployment.new(destination: "staging")
  commit = ENV.fetch("RELEASE_COMMIT")
  ci_run_id = Ops::ReleaseSupport.run_id(ENV.fetch("RELEASE_CI_RUN_ID"))
  ci = Ops::ReleaseSupport.run(deployment.repository, ci_run_id)
  Ops::ReleaseManifest.validate_ci!(run: ci, expected_repository: deployment.repository)
  abort "CI-Commit stimmt nicht überein" unless ci.fetch("head_sha") == commit
  image = Ops::ReleaseManifest::IMAGES.fetch(deployment.repository)
  digest = ENV.fetch("RELEASE_DIGEST")
  abort "Build-Digest stimmt nicht mit Registry überein" unless Ops::ReleaseSupport.registry_digest(image:, commit:) == digest
  deployment.prepare!
  deployment.with_lock do
    deployment.deploy!(commit:, digest:)
    puts "Staging: HTTPS des Partnerprojekts prüfen"
    deployment.smoke_peer!
    # Read-only metadata/schema queries use existing app connections. No stage role is granted production access.
    proof = Ops::CompatibilityProbe.call(project: deployment.project, candidate: { "commit" => commit, "digest" => digest }, remote: deployment.remote,
      master_keys: { deployment.project => ENV.fetch("RAILS_MASTER_KEY"), deployment.peer => ENV.fetch("STAGING_PEER_RAILS_MASTER_KEY") })
    manifest = { "schema_version" => 2, "repository" => deployment.repository, "commit" => commit, "image" => image, "digest" => digest,
      "ci_run_id" => ci_run_id, "staging_run_id" => Ops::ReleaseSupport.run_id(ENV.fetch("GITHUB_RUN_ID")),
      "deployment_config_sha256" => Ops::ReleaseManifest.deployment_config_sha256(root: Dir.pwd),
      "paired_app" => proof.fetch("paired_app"), "compatible_peers" => [ proof.fetch("paired_app"), proof.fetch("production_peer") ].uniq }
    Ops::ReleaseManifest.validate_contents!(manifest:, expected_repository: deployment.repository)
    deployment.notify_sentry!
    path = ENV.fetch("RELEASE_MANIFEST_PATH") { File.join(ENV.fetch("RUNNER_TEMP"), "staging-release.json") }
    Ops::ReleaseSupport.write_json(path, manifest)
  end
rescue KeyError, JSON::ParserError, Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error, Ops::DeployImageProof::Error, Ops::DeployLock::Error, Timeout::Error => error
  warn "Staging-Prüfung abgebrochen (#{error.class.name})"
  abort "Staging-Nachweis nicht erstellt: Quelle, Deploy, Smoke oder Kompatibilität fehlgeschlagen. Produktion bleibt unverändert."
end
