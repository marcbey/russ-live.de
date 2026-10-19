require "test_helper"
require "open3"

class CiImageTest < ActiveSupport::TestCase
  test "the image from the validated CI run exports its immutable digest" do
    with_image do |manifest, env, output|
      File.write(env.fetch("CI_IMAGE_PATH"), JSON.generate(manifest))
      stdout, stderr, status = read_image(env)

      assert status.success?, stdout + stderr
      assert_equal "digest=sha256:#{'b' * 64}\n", File.read(output)
    end
  end

  test "a foreign commit run repository image or malformed digest never exports a release" do
    mutations = [
      ->(image) { image["commit"] = "c" * 40 },
      ->(image) { image["ci_run_id"] = 12 },
      ->(image) { image["ci_run_id"] = "11" },
      ->(image) { image["repository"] = "other/project" },
      ->(image) { image["image"] = "ghcr.io/marcbey/stuttgart-live-de" },
      ->(image) { image["digest"] = "sha256:bad\ninjected=true" },
      ->(image) { image.delete("digest") }
    ]
    mutations.each do |mutate|
      with_image do |manifest, env, output|
        mutate.call(manifest)
        File.write(env.fetch("CI_IMAGE_PATH"), JSON.generate(manifest))
        _, _, status = read_image(env)

        assert_not status.success?, manifest.inspect
        assert_empty File.read(output)
      end
    end
  end

  private

  def with_image
    Dir.mktmpdir do |root|
      output = File.join(root, "output")
      File.write(output, "")
      env = { "GITHUB_REPOSITORY" => "marcbey/russ-live.de", "RELEASE_COMMIT" => "a" * 40,
        "RELEASE_CI_RUN_ID" => "11", "CI_IMAGE_PATH" => File.join(root, "image.json"), "GITHUB_OUTPUT" => output }
      manifest = { "repository" => "marcbey/russ-live.de", "ci_run_id" => 11, "commit" => "a" * 40,
        "image" => "ghcr.io/marcbey/russ-live-de", "digest" => "sha256:#{'b' * 64}" }
      yield manifest, env, output
    end
  end

  def read_image(env)
    Open3.capture3(env, "mise", "exec", "--", "ruby", Rails.root.join("script/ops/ci_image.rb").to_s)
  end
end
