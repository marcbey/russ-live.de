require "digest"
require "time"

module Ops
  module ReleaseManifest
    Error = Class.new(StandardError)
    IMAGES = { "marcbey/stuttgart-live.de" => "ghcr.io/marcbey/stuttgart-live-de", "marcbey/russ-live.de" => "ghcr.io/marcbey/russ-live-de" }.freeze
    FIELDS = %w[schema_version repository commit image digest ci_run_id staging_run_id deployment_config_sha256 paired_app compatible_peers].freeze

    def self.validate!(manifest:, expected_repository:, ci_run:, staging_run:, registry_digest:, peer_production:)
      validate_provenance!(manifest:, expected_repository:, ci_run:, staging_run:, registry_digest:)
      validate_peer!(manifest:, peer: peer_production)
      true
    end

    def self.validate_provenance!(manifest:, expected_repository:, ci_run:, staging_run:, registry_digest:)
      validate_contents!(manifest:, expected_repository:)
      validate_ci!(run: ci_run, expected_repository:)
      valid = ci_run["id"] == manifest["ci_run_id"] && ci_run["head_sha"] == manifest["commit"] &&
        trusted_run?(staging_run, expected_repository) && staging_run["id"] == manifest["staging_run_id"] &&
        staging_run["event"] == "workflow_run" && staging_run["path"] == ".github/workflows/deploy-staging.yml" &&
        registry_digest == manifest["digest"]
      raise Error, "Freigabenachweis passt nicht zu Run, Image oder produktivem Peer" unless valid

      artifact = staging_run["artifact"]
      valid_artifact = artifact.is_a?(Hash) && artifact["id"].is_a?(Integer) && artifact["id"].positive? &&
        artifact["name"] == "staging-release" && artifact["expired"] == false &&
        artifact.dig("workflow_run", "id") == staging_run["id"] &&
        artifact.dig("workflow_run", "head_branch") == "main" &&
        artifact.dig("workflow_run", "head_repository_id") == staging_run.dig("repository", "id") &&
        artifact.dig("workflow_run", "repository_id") == staging_run.dig("repository", "id") &&
        Time.iso8601(artifact.fetch("expires_at")) > Time.now.utc
      raise Error, "Staging-Artefakt fehlt, ist abgelaufen oder stammt aus einem anderen Run" unless valid_artifact
      true
    rescue KeyError, ArgumentError, TypeError
      raise Error, "Ungültiger Freigabenachweis"
    end

    def self.validate_contents!(manifest:, expected_repository:)
      image = IMAGES[expected_repository]
      peer_image = (IMAGES.values - [ image ]).first
      valid = image && manifest.is_a?(Hash) && manifest.keys.sort == FIELDS.sort &&
        manifest["schema_version"] == 2 && manifest["repository"] == expected_repository && manifest["image"] == image &&
        sha?(manifest["commit"]) && valid_identity?(manifest["paired_app"], expected_image: peer_image) &&
        manifest["digest"].to_s.match?(/\Asha256:[a-f0-9]{64}\z/) &&
        manifest["deployment_config_sha256"].to_s.match?(/\A[a-f0-9]{64}\z/) &&
        %w[ci_run_id staging_run_id].all? { |key| manifest[key].is_a?(Integer) && manifest[key].positive? } &&
        manifest["compatible_peers"].is_a?(Array) && !manifest["compatible_peers"].empty? &&
        manifest["compatible_peers"].uniq == manifest["compatible_peers"] &&
        manifest["compatible_peers"].all? { |peer| valid_identity?(peer, expected_image: peer_image) } &&
        manifest["compatible_peers"].include?(manifest["paired_app"])
      raise Error, "Release-Manifest enthält ungültige oder zusätzliche Felder" unless valid
      true
    end

    def self.image_identity(metadata)
      raise Error, "Peer-Identität fehlt" unless metadata.is_a?(Hash)
      metadata.slice("image", "commit", "digest")
    end

    def self.valid_identity?(identity, expected_image:)
      identity.is_a?(Hash) && identity.keys.sort == %w[commit digest image] && identity["image"] == expected_image &&
        sha?(identity["commit"]) && identity["digest"].to_s.match?(/\Asha256:[a-f0-9]{64}\z/)
    end

    def self.validate_peer!(manifest:, peer:)
      identity = image_identity(peer)
      raise Error, "Produktives Peer-Image wurde mit dieser Version nicht geprüft" unless manifest.fetch("compatible_peers").include?(identity)
      true
    end

    def self.validate_ci!(run:, expected_repository:)
      unless trusted_run?(run, expected_repository) && run["event"] == "push" && run["path"] == ".github/workflows/ci.yml" && sha?(run["head_sha"])
        raise Error, "Quell-CI muss ein erfolgreicher Main-Push im eigenen Repository sein"
      end
      true
    end

    def self.deployment_config_sha256(root:)
      patterns = %w[config/deploy*.yml config/nginx* config/nginx/**/* .kamal/hooks/pre-deploy
        app/lib/hetzner_deploy_config.rb app/lib/deployment_environment.rb script/ops/deploy_release.rb script/ops/verify_deploy_image.rb]
      files = patterns.flat_map { |pattern| Dir.glob(File.join(root, pattern)) }.select { |path| File.file?(path) }.uniq.sort
      digest = Digest::SHA256.new
      files.each do |path|
        digest << path.delete_prefix("#{root}/") << "\0" << File.binread(path) << "\0"
      end
      digest.hexdigest
    end

    def self.trusted_run?(run, repository)
      run.is_a?(Hash) && run["status"] == "completed" && run["conclusion"] == "success" && run["head_branch"] == "main" &&
        run.dig("repository", "full_name") == repository && run.dig("head_repository", "full_name") == repository &&
        run.dig("repository", "id").is_a?(Integer) && run.dig("repository", "id").positive? &&
        run.dig("head_repository", "id") == run.dig("repository", "id")
    end

    def self.sha?(value)
      value.is_a?(String) && value.match?(/\A[a-f0-9]{40}\z/)
    end
  end
end
