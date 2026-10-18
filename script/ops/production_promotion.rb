require_relative "production_approval"
require_relative "deployment_remote"

module Ops
  module ProductionPromotion
    def self.call(deployment:, manifest:, mode:, production_fingerprint:, approval: ProductionApproval.new(repository: deployment.repository), evidence: ReleaseEvidence)
      refusal = nil
      deployment.with_lock do
        begin
          approval.validate_environment!
          production = deployment.remote.running(project: deployment.project, destination: "hetzner")
          actual = Digest::SHA256.hexdigest(JSON.generate(ImageFingerprint.canonical(ReleaseManifest.image_identity(production))))
          raise ReleaseSupport::Error, "Produktionsstand geändert: Freigabe mit aktuellem Vergleich erneut vorbereiten" unless actual == production_fingerprint
          peer = deployment.remote.running(project: deployment.peer, destination: "hetzner")
          evidence.validate(repository: deployment.repository, manifest:, peer_production: peer)
          approval.validate_current!(manifest:, remote: deployment.remote, project: deployment.project, mode:)
        rescue ReleaseSupport::Error, ReleaseManifest::Error, DeployImageProof::Error, KeyError, JSON::ParserError => error
          # A refusal before host mutation must not leave a persistent operation fence.
          refusal = error
          next
        end
        deployment.deploy!(commit: manifest.fetch("commit"), digest: manifest.fetch("digest"))
        deployment.notify_sentry!
      end
      raise refusal if refusal
      true
    end
  end
end
