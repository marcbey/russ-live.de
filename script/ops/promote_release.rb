ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __dir__)
require_relative "deploy_release"
require_relative "production_promotion"

begin
  Dir.chdir(ENV.fetch("RELEASE_CHECKOUT"))
  deployment = Ops::ReleaseDeployment.new(destination: "hetzner")
  manifest = Ops::ReleaseEvidence.resolve(repository: deployment.repository, staging_run_id: ENV.fetch("RELEASE_STAGING_RUN_ID"))
  Ops::ProductionApproval.validate_binding!(manifest:, commit: ENV.fetch("RELEASE_EXPECTED_COMMIT"), digest: ENV.fetch("RELEASE_EXPECTED_DIGEST"),
    fingerprint: ENV.fetch("RELEASE_EXPECTED_MANIFEST_SHA256"))
  actual_config = Ops::ReleaseManifest.deployment_config_sha256(root: Dir.pwd)
  abort "Deploy-Konfiguration entspricht nicht dem Staging-Nachweis" unless manifest.fetch("deployment_config_sha256") == actual_config
  deployment.prepare!
  Ops::ProductionPromotion.call(deployment:, manifest:, mode: ENV.fetch("RELEASE_MODE"), production_fingerprint: ENV.fetch("RELEASE_EXPECTED_PRODUCTION_SHA256"))
rescue KeyError, JSON::ParserError, Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error, Ops::DeployImageProof::Error, Ops::DeployLock::Error, Timeout::Error => error
  warn "Produktionsfreigabe verweigert oder Deploy fehlgeschlagen: #{error.message}"
  exit 1
end
