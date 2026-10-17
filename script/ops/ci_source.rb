require_relative "release_support"

begin
  repository = Ops::ReleaseSupport.repository
  event = JSON.parse(File.read(ENV.fetch("GITHUB_EVENT_PATH")))
  declared = event.fetch("workflow_run")
  run = Ops::ReleaseSupport.run(repository, declared.fetch("id"))
  Ops::ReleaseManifest.validate_ci!(run:, expected_repository: repository)
  abort "CI-Payload stimmt nicht mit GitHub API überein" unless run.fetch("head_sha") == declared.fetch("head_sha")
  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") do |file|
    file.puts "commit=#{run.fetch('head_sha')}"
    file.puts "ci_run_id=#{run.fetch('id')}"
  end
rescue KeyError, JSON::ParserError, Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error
  abort "Staging-Quelle verweigert: keine erfolgreiche eigene Main-CI."
end
