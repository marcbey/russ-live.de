require_relative "release_evidence"

begin
  repository = Ops::ReleaseSupport.repository
  manifest = Ops::ReleaseEvidence.resolve(repository:, staging_run_id: ENV.fetch("RELEASE_STAGING_RUN_ID"))
  path = ENV.fetch("RELEASE_MANIFEST_PATH") { File.join(ENV.fetch("RUNNER_TEMP"), "staging-release.json") }
  Ops::ReleaseSupport.write_json(path, manifest)
  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |file| file.puts "commit=#{manifest.fetch('commit')}" }
  puts "GitHub-Provenienz und Image-Digest geprüft; produktiver Peer wird unter der Serversperre geprüft."
rescue KeyError, JSON::ParserError, Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error
  abort "Produktion verweigert: Staging-Nachweis fehlt, ist abgelaufen oder ungültig. Kein Neubau."
end
