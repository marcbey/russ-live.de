require "tmpdir"
require_relative "release_support"

module Ops
  class ReleaseEvidence
    def self.resolve(repository:, staging_run_id:)
      id = ReleaseSupport.run_id(staging_run_id)
      stage = ReleaseSupport.run(repository, id)
      unless ReleaseManifest.trusted_run?(stage, repository) && stage["event"] == "workflow_run" && stage["path"] == ".github/workflows/deploy-staging.yml"
        raise ReleaseSupport::Error, "Kein erfolgreicher eigener Main-Staging-Run"
      end
      artifacts = ReleaseSupport.github_json("repos/#{repository}/actions/runs/#{id}/artifacts?per_page=100").fetch("artifacts")
      selected = artifacts.select { |artifact| artifact["name"] == "staging-release" && artifact["expired"] == false }
      raise ReleaseSupport::Error, "Genau ein gültiger Staging-Nachweis erforderlich" unless selected.one?
      stage["artifact"] = selected.first
      manifest = Dir.mktmpdir("release-evidence-") do |directory|
        ReleaseSupport.capture("gh", "run", "download", id.to_s, "--repo", repository, "--name", "staging-release", "--dir", directory)
        path = File.join(directory, "staging-release.json")
        valid = Dir.children(directory) == [ "staging-release.json" ] && File.file?(path) && !File.symlink?(path) && File.size(path) <= 65_536
        raise ReleaseSupport::Error, "Unerwarteter Inhalt im Freigabeartefakt" unless valid
        JSON.parse(File.read(path))
      end
      validate(repository:, manifest:, stage:)
      manifest
    end

    def self.validate(repository:, manifest:, stage: nil, peer_production: nil)
      ReleaseManifest.validate_contents!(manifest:, expected_repository: repository)
      unless stage
        current = resolve(repository:, staging_run_id: manifest.fetch("staging_run_id"))
        raise ReleaseSupport::Error, "Freigabeartefakt wurde seit der Auswahl ersetzt" unless current == manifest
        ReleaseManifest.validate_peer!(manifest:, peer: peer_production) if peer_production
        return true
      end
      stage ||= ReleaseSupport.run(repository, manifest.fetch("staging_run_id"))
      unless stage["artifact"]
        artifacts = ReleaseSupport.github_json("repos/#{repository}/actions/runs/#{manifest.fetch('staging_run_id')}/artifacts?per_page=100").fetch("artifacts")
        selected = artifacts.select { |artifact| artifact["name"] == "staging-release" && artifact["expired"] == false }
        raise ReleaseSupport::Error, "Staging-Artefakt fehlt oder ist nicht eindeutig" unless selected.one?
        stage["artifact"] = selected.first
      end
      ci_run = ReleaseSupport.run(repository, manifest.fetch("ci_run_id"))
      registry_digest = ReleaseSupport.registry_digest(image: manifest.fetch("image"), commit: manifest.fetch("commit"))
      args = { manifest:, expected_repository: repository, ci_run:, staging_run: stage, registry_digest: }
      if peer_production
        ReleaseManifest.validate!(**args, peer_production:)
      else
        ReleaseManifest.validate_provenance!(**args)
      end
    end
  end
end
