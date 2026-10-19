require "test_helper"
require "support/deploy_config_helper"
require_relative "../../script/ops/deployment_remote"

class DeploymentRemoteTest < ActiveSupport::TestCase
  include DeployConfigHelper

  IMAGE = "ghcr.io/marcbey/russ-live-de"
  COMMIT = "a" * 40
  TAG = "#{IMAGE}:#{COMMIT}"
  DIGEST = "sha256:#{'d' * 64}"

  test "cached images retain the digest recorded when their container was deployed" do
    remote = fixture_remote(digests: [ "sha256:#{'b' * 64}", DIGEST ])
    identity = remote.running(project: "russ_live_de", destination: "staging")
    assert_equal({ "container" => "123456abcdef", "commit" => COMMIT, "image" => IMAGE, "digest" => DIGEST }, identity)
  end

  test "a recorded digest absent from the local image cannot identify the container" do
    remote = fixture_remote(digests: [ "sha256:#{'b' * 64}" ])
    assert_raises(Ops::DeployImageProof::Error) { remote.running(project: "russ_live_de", destination: "staging") }
  end

  test "recorded digests cannot hide a different running image" do
    remote = fixture_remote(digests: [ "sha256:#{'b' * 64}", DIGEST ], container_id: "sha256:#{'e' * 64}")
    assert_raises(Ops::DeployImageProof::Error) { remote.running(project: "russ_live_de", destination: "staging") }
  end

  test "legacy containers need exactly one unambiguous digest" do
    remote = fixture_remote(digests: [ "sha256:#{'b' * 64}" ], recorded_digest: "")
    assert_equal "sha256:#{'b' * 64}", remote.running(project: "russ_live_de", destination: "hetzner").fetch("digest")
    remote = fixture_remote(digests: [ "sha256:#{'b' * 64}", DIGEST ], recorded_digest: "")
    assert_raises(Ops::ReleaseSupport::Error) { remote.running(project: "russ_live_de", destination: "staging") }
  end

  test "Kamal records the proven release digest on every role in both destinations" do
    %w[staging hetzner].each do |destination|
      raw = render_deploy_config(destination:, env: { "RELEASE_DIGEST" => DIGEST })
      config = Kamal::Configuration.new(raw.symbolize_keys, destination:)
      config.roles.each { |role| assert_equal DIGEST, role.labels.transform_keys(&:to_s).fetch("live.release_digest") }
    end
  end

  test "all running roles are verified in one SSH snapshot" do
    remote, commands = verification_remote

    assert remote.verify_running!(project: "russ_live_de", destination: "hetzner", commit: COMMIT, digest: DIGEST)
    assert_equal 1, commands.size, "the complete role proof must need only one SSH connection"
  end

  test "the batched proof rejects a wrong job image or release digest" do
    [ { "image" => "#{IMAGE}:#{'b' * 40}" }, { "id" => "sha256:#{'e' * 64}" }, { "digest" => "sha256:#{'e' * 64}" } ].each do |change|
      containers = role_containers
      containers.last.merge!(change)
      remote, = verification_remote(containers:)

      assert_raises(Ops::DeployImageProof::Error) do
        remote.verify_running!(project: "russ_live_de", destination: "hetzner", commit: COMMIT, digest: DIGEST)
      end
    end
  end

  test "the batched proof rejects missing duplicated or extra roles" do
    web, job = role_containers
    [ [], [ web ], [ web, job, job ], [ web, job.merge("role" => "unexpected") ] ].each do |containers|
      remote, = verification_remote(containers:)

      assert_raises(Ops::ReleaseSupport::Error) do
        remote.verify_running!(project: "russ_live_de", destination: "hetzner", commit: COMMIT, digest: DIGEST)
      end
    end
  end

  test "the batched proof rejects malformed container identities" do
    containers = role_containers
    containers.last["container"] = "invalid"
    remote, = verification_remote(containers:)

    assert_raises(Ops::ReleaseSupport::Error) do
      remote.verify_running!(project: "russ_live_de", destination: "hetzner", commit: COMMIT, digest: DIGEST)
    end
  end

  private

  def role_containers
    [
      { "container" => "123456abcdef", "image" => TAG, "id" => "sha256:#{'c' * 64}", "digest" => DIGEST, "role" => "web" },
      { "container" => "abcdef123456", "image" => TAG, "id" => "sha256:#{'c' * 64}", "digest" => DIGEST, "role" => "job" }
    ]
  end

  def verification_remote(containers: role_containers)
    remote = Ops::DeploymentRemote.new(key_path: "/unused")
    commands = []
    image = { "id" => "sha256:#{'c' * 64}", "digests" => [ "#{IMAGE}@#{DIGEST}" ] }
    remote.define_singleton_method(:capture) do |command, **|
      commands << command
      case command
      when /\Adocker image inspect / then JSON.generate(image)
      when /\Adocker ps / then containers.map { |container| container.fetch("container") }.join("\n")
      when /\Adocker inspect / then JSON.generate(containers.find { |container| command.end_with?(container.fetch("container")) })
      when /\Aset -eu\n/ then JSON.generate("image" => image, "containers" => containers)
      else raise "Unexpected remote command: #{command}"
      end
    end
    [ remote, commands ]
  end

  def fixture_remote(digests:, container_id: "sha256:#{'c' * 64}", recorded_digest: DIGEST)
    remote = Ops::DeploymentRemote.new(key_path: "/unused")
    image = { "id" => "sha256:#{'c' * 64}", "digests" => digests.map { |digest| "#{IMAGE}@#{digest}" } }
    remote.define_singleton_method(:capture) do |command, **|
      case command
      when /\Adocker ps / then "123456abcdef\n"
      when /\Adocker inspect / then JSON.generate("image" => TAG, "id" => container_id, "digest" => recorded_digest)
      when /\Adocker image inspect / then JSON.generate(image)
      else raise "Unexpected remote command: #{command}"
      end
    end
    remote
  end
end
