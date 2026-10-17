require "shellwords"
require_relative "release_support"

module Ops
  module DeployImageProof
    Error = Class.new(StandardError)

    def self.validate!(image_metadata:, container_metadata: nil, expected_image:, expected_digest:)
      match = expected_image.to_s.match(/\A(ghcr\.io\/marcbey\/(?:stuttgart|russ)-live-de):[a-f0-9]{40}\z/)
      valid = match && expected_digest.to_s.match?(/\Asha256:[a-f0-9]{64}\z/) &&
        image_metadata.is_a?(Hash) && image_metadata["id"].to_s.match?(/\Asha256:[a-f0-9]{64}\z/) &&
        Array(image_metadata["digests"]).include?("#{match[1]}@#{expected_digest}")
      if container_metadata
        valid &&= container_metadata["image"] == expected_image && container_metadata["id"] == image_metadata["id"]
      end
      raise Error, "Lokales oder laufendes Image entspricht nicht dem geprüften Digest" unless valid
      true
    end
  end

  class DeploymentRemote
    PROJECTS = { "stuttgart_live_de" => "ghcr.io/marcbey/stuttgart-live-de", "russ_live_de" => "ghcr.io/marcbey/russ-live-de" }.freeze

    def initialize(key_path:, host: "46.225.224.194")
      raise ReleaseSupport::Error, "Unbekannter Deployment-Host" unless host == "46.225.224.194"
      @host, @key_path = host, key_path
    end

    def capture(command, input: nil, output_path: nil)
      ReleaseSupport.capture("ssh", "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=10",
        "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=2", "-i", @key_path, "deploy@#{@host}", command, input:, output_path:)
    end

    def image_metadata(reference)
      raise ReleaseSupport::Error, "Unbekannte Image-Referenz" unless reference.match?(/\Aghcr\.io\/marcbey\/(?:stuttgart|russ)-live-de:[a-f0-9]{40}\z/)
      JSON.parse(capture("docker image inspect --format #{q('{"id":{{json .Id}},"digests":{{json .RepoDigests}}}')} #{q(reference)}"))
    end

    def running(project:, destination:)
      validate_target!(project, destination)
      ids = capture("docker ps -q --filter label=service=#{project} --filter label=destination=#{destination} --filter label=role=web").split
      raise ReleaseSupport::Error, "Kein eindeutig laufender Web-Container" unless ids.one? && ids.first.match?(/\A[a-f0-9]{12,64}\z/)
      container = ids.first
      metadata = JSON.parse(capture("docker inspect --format #{q('{"image":{{json .Config.Image}},"id":{{json .Image}}}')} #{container}"))
      image = PROJECTS.fetch(project)
      match = metadata.fetch("image").match(/\A#{Regexp.escape(image)}:([a-f0-9]{40})\z/)
      raise ReleaseSupport::Error, "Laufender Commit nicht eindeutig bestimmbar" unless match
      local_image = image_metadata(metadata.fetch("image"))
      digests = Array(local_image["digests"]).filter_map { |value| value.delete_prefix("#{image}@") if value.start_with?("#{image}@") }.uniq
      raise ReleaseSupport::Error, "Laufender Digest fehlt" unless digests.one? && digests.first.match?(/\Asha256:[a-f0-9]{64}\z/)
      DeployImageProof.validate!(image_metadata: local_image, container_metadata: metadata, expected_image: metadata.fetch("image"), expected_digest: digests.first)
      { "container" => container, "commit" => match[1], "image" => image, "digest" => digests.first }
    end

    def verify_running!(project:, destination:, commit:, digest:, roles: %w[web job])
      validate_target!(project, destination)
      tag = "#{PROJECTS.fetch(project)}:#{commit}"
      image = image_metadata(tag)
      seen = []
      ids = capture("docker ps -q --filter label=service=#{project} --filter label=destination=#{destination}").split
      raise ReleaseSupport::Error, "Keine laufenden App-Container" if ids.empty?
      ids.each do |id|
        raise ReleaseSupport::Error, "Ungültige Container-ID" unless id.match?(/\A[a-f0-9]{12,64}\z/)
        metadata = JSON.parse(capture("docker inspect --format #{q('{"image":{{json .Config.Image}},"id":{{json .Image}},"role":{{json (index .Config.Labels "role")}}}')} #{id}"))
        DeployImageProof.validate!(image_metadata: image, container_metadata: metadata, expected_image: tag, expected_digest: digest)
        seen << metadata.fetch("role")
      end
      raise ReleaseSupport::Error, "App-Rolle fehlt oder ist doppelt aktiv" unless seen.sort == roles.sort
      true
    end

    def export(project:, destination:, mode:, path:)
      raise ReleaseSupport::Error, "Produktionsdaten werden nicht exportiert" unless (destination == "staging" && mode == "data") || (destination == "hetzner" && mode == "schema")
      app = running(project:, destination:)
      script = File.read(File.join(__dir__, "compatibility_export.rb"))
      script = "PROJECT = #{project.inspect}\nEXPORT_MODE = #{mode.inspect}\n" + script
      capture("docker exec -i #{app.fetch('container')} bundle exec ruby -", input: script, output_path: path)
      app
    end

    def copy_from(container:, source:, target:)
      raise ReleaseSupport::Error, "Ungültiger Container oder Credential-Pfad" unless container.match?(/\A[a-f0-9]{12,64}\z/) && source == "/rails/config/credentials/staging.yml.enc"
      capture("docker cp #{container}:#{source} -", output_path: "#{target}.tar")
      ReleaseSupport.capture("tar", "-xOf", "#{target}.tar", "staging.yml.enc", output_path: target)
      File.unlink("#{target}.tar")
    end

    private

    def validate_target!(project, destination)
      raise ReleaseSupport::Error, "Unbekanntes App-Ziel" unless PROJECTS.key?(project) && %w[staging hetzner].include?(destination)
    end

    def q(value)
      Shellwords.escape(value)
    end
  end
end
