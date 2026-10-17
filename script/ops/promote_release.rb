require_relative "deploy_release"
require_relative "release_evidence"

begin
  deployment = Ops::ReleaseDeployment.new(destination: "hetzner")
  path = ENV.fetch("RELEASE_MANIFEST_PATH") { File.join(ENV.fetch("RUNNER_TEMP"), "staging-release.json") }
  manifest = JSON.parse(File.read(path))
  Ops::ReleaseEvidence.validate(repository: deployment.repository, manifest:)
  actual_config = Ops::ReleaseManifest.deployment_config_sha256(root: Dir.pwd)
  abort "Deploy-Konfiguration entspricht nicht dem Staging-Nachweis" unless manifest.fetch("deployment_config_sha256") == actual_config
  deployment.prepare!
  deployment.with_lock do
    peer = deployment.remote.running(project: deployment.peer, destination: "hetzner")
    Ops::ReleaseEvidence.validate(repository: deployment.repository, manifest:, peer_production_commit: peer.fetch("commit"))
    deployment.deploy!(commit: manifest.fetch("commit"), digest: manifest.fetch("digest"))
    deployment.notify_sentry!
  end
rescue KeyError, JSON::ParserError, Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error, Ops::DeployImageProof::Error, Ops::DeployLock::Error, Timeout::Error
  abort "Produktionsfreigabe verweigert oder Deploy fehlgeschlagen. Kein Neubau, kein latest-Fallback und kein Proxy-Reboot."
end
