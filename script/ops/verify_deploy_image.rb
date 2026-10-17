require_relative "deployment_remote"

begin
  project = File.read("config/deploy.yml")[/^service:\s+(\w+)$/, 1]
  abort "Unbekannter App-Service" unless Ops::DeploymentRemote::PROJECTS.key?(project)
  repository = ENV.fetch("GITHUB_REPOSITORY", project == "russ_live_de" ? "marcbey/russ-live.de" : "marcbey/stuttgart-live.de")
  image = Ops::ReleaseManifest::IMAGES.fetch(repository)
  commit = ENV.fetch("KAMAL_VERSION")
  digest = ENV.fetch("RELEASE_DIGEST")
  abort "Freigabeversion fehlt" unless Ops::ReleaseManifest.sha?(commit) && %w[staging hetzner].include?(ENV["KAMAL_DESTINATION"])
  remote = Ops::DeploymentRemote.new(key_path: ENV.fetch("KAMAL_SSH_KEY_PATH"))
  tag = "#{image}:#{commit}"
  Ops::DeployImageProof.validate!(image_metadata: remote.image_metadata(tag), expected_image: tag, expected_digest: digest)
  puts "Kamal-Pull geprüft: #{commit} #{digest}"
rescue KeyError, Ops::ReleaseSupport::Error, Ops::DeployImageProof::Error
  abort "Kamal-Start verweigert: kein gültiger Image-Digest-Nachweis."
end
