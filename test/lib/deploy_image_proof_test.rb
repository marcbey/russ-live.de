require "test_helper"
require_relative "../../script/ops/deployment_remote"

class DeployImageProofTest < ActiveSupport::TestCase
  test "pulled SHA tag and running container must identify the same tested digest" do
    tag = "ghcr.io/marcbey/stuttgart-live-de:#{'a' * 40}"
    digest = "sha256:#{'b' * 64}"
    image = { "id" => "sha256:#{'c' * 64}", "digests" => [ "ghcr.io/marcbey/stuttgart-live-de@#{digest}" ] }
    container = { "id" => image["id"], "image" => tag }
    assert Ops::DeployImageProof.validate!(image_metadata: image, container_metadata: container, expected_image: tag, expected_digest: digest)
    assert_raises(Ops::DeployImageProof::Error) { Ops::DeployImageProof.validate!(image_metadata: image, container_metadata: container.merge("id" => "sha256:#{'d' * 64}"), expected_image: tag, expected_digest: digest) }
    assert_raises(Ops::DeployImageProof::Error) { Ops::DeployImageProof.validate!(image_metadata: image.merge("digests" => []), container_metadata: container, expected_image: tag, expected_digest: digest) }
    assert_raises(Ops::DeployImageProof::Error) { Ops::DeployImageProof.validate!(image_metadata: image, container_metadata: container.merge("image" => "other:latest"), expected_image: tag, expected_digest: digest) }
  end
end
