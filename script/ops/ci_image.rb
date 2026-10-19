require_relative "release_support"

begin
  repository = Ops::ReleaseSupport.repository
  commit = ENV.fetch("RELEASE_COMMIT")
  ci_run_id = Ops::ReleaseSupport.run_id(ENV.fetch("RELEASE_CI_RUN_ID"))
  manifest = JSON.parse(File.read(ENV.fetch("CI_IMAGE_PATH")))
  valid = manifest.is_a?(Hash) && manifest.keys.sort == %w[ci_run_id commit digest image repository] &&
    manifest["repository"] == repository && manifest["commit"] == commit && manifest["ci_run_id"] == ci_run_id &&
    Ops::ReleaseManifest.valid_identity?(manifest.slice("commit", "image", "digest"), expected_image: Ops::ReleaseManifest::IMAGES.fetch(repository))
  abort "CI-Image passt nicht zum geprüften Main-Lauf" unless valid

  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |file| file.puts "digest=#{manifest.fetch('digest')}" }
rescue KeyError, JSON::ParserError, SystemCallError, Ops::ReleaseSupport::Error
  abort "CI-Image verweigert: gültiger Build-Nachweis des erfolgreichen Main-Laufs erforderlich."
end
