require "json"
require "open3"
require "digest"
require "fileutils"
require_relative "release_manifest"

module Ops
  module ImageFingerprint
    # Docker28 classic inspect adds these empty defaults; Docker29 omits them.
    # Keep every unknown field and every non-default value in the fingerprint.
    LEGACY_EMPTY_CONFIG = {
      "Hostname" => "", "Domainname" => "", "AttachStdin" => false, "AttachStdout" => false,
      "AttachStderr" => false, "Tty" => false, "OpenStdin" => false, "StdinOnce" => false,
      "Image" => "", "Volumes" => nil, "OnBuild" => nil
    }.freeze

    def self.call(metadata)
      valid = metadata["Os"] == "linux" && %w[amd64 arm64].include?(metadata["Architecture"]) &&
        metadata["Config"].is_a?(Hash) && metadata.dig("RootFS", "Type") == "layers" &&
        metadata.dig("RootFS", "Layers").is_a?(Array) && !metadata.dig("RootFS", "Layers").empty? &&
        metadata.dig("RootFS", "Layers").all? { |value| value.match?(/\Asha256:[a-f0-9]{64}\z/) }
      raise ReleaseSupport::Error, "Unvollständige Image-Laufzeitidentität" unless valid
      value = metadata.slice("Os", "Architecture", "Config", "RootFS")
      value["Config"] = value.fetch("Config").reject do |key, item|
        LEGACY_EMPTY_CONFIG.key?(key) && item == LEGACY_EMPTY_CONFIG.fetch(key)
      end
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def self.canonical(value)
      case value
      when Hash then value.sort.to_h.transform_values { |item| canonical(item) }
      when Array then value.map { |item| canonical(item) }
      else value
      end
    end
  end

  module ReleaseSupport
    Error = Class.new(StandardError)

    def self.capture(*command, env: {}, input: nil, output_path: nil)
      value = nil
      Open3.popen3(env, *command) do |stdin, stdout, stderr, waiter|
        writer = Thread.new do
          stdin.write(input) if input
        ensure
          stdin.close
        end
        drain = Thread.new { stderr.each_line { |_line| } }
        if output_path
          File.open(output_path, "wb", 0o600) { |file| IO.copy_stream(stdout, file) }
        else
          value = stdout.read
        end
        writer.value
        success = waiter.value.success?
        drain.value
        raise Error, "Befehl fehlgeschlagen: #{File.basename(command.first)} (keine Secrets oder Rohdaten ausgegeben)" unless success
      end
      value
    end

    def self.repository
      value = ENV.fetch("GITHUB_REPOSITORY")
      raise Error, "Unbekanntes Release-Repository" unless ReleaseManifest::IMAGES.key?(value)
      value
    end

    def self.run_id(value)
      raise Error, "Positive Run-ID erforderlich" unless value.to_s.match?(/\A[1-9][0-9]*\z/)
      Integer(value)
    end

    def self.github_json(path)
      JSON.parse(capture("gh", "api", path))
    end

    def self.run(repository, id)
      github_json("repos/#{repository}/actions/runs/#{run_id(id)}")
    end

    def self.registry_digest(image:, commit:)
      raise Error, "Unbekanntes Registry-Image" unless ReleaseManifest::IMAGES.value?(image) && ReleaseManifest.sha?(commit)
      raw = capture("docker", "buildx", "imagetools", "inspect", "--raw", "#{image}:#{commit}")
      parsed = JSON.parse(raw)
      raise Error, "Kein Registry-Manifest" unless parsed["schemaVersion"] == 2
      "sha256:#{Digest::SHA256.hexdigest(raw)}"
    end

    def self.write_json(path, data)
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      File.open(path, "w", 0o600) { |file| file.puts JSON.pretty_generate(data) }
    end
  end
end
