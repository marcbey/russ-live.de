require_relative "production_approval"
require_relative "deployment_remote"
require_relative "deploy_lock"
require_relative "../../app/lib/hetzner_deploy_config"

begin
  repository = Ops::ReleaseSupport.repository
  selection = Ops::ProductionApproval.selection(repository:, event_name: ENV.fetch("GITHUB_EVENT_NAME"), ref: ENV.fetch("GITHUB_REF"),
    event: JSON.parse(File.read(ENV.fetch("GITHUB_EVENT_PATH"))))
  approval = Ops::ProductionApproval.new(repository:)
  approval.validate_environment!
  manifest = Ops::ReleaseEvidence.resolve(repository:, staging_run_id: selection.fetch(:staging_run_id))
  project = repository == "marcbey/stuttgart-live.de" ? "stuttgart_live_de" : "russ_live_de"
  host = HetznerDeployConfig.web_host(destination: "staging")
  host_key = HetznerDeployConfig.ssh_host_key(destination: "staging")
  raise Ops::ReleaseSupport::Error, "Unbekannter Deployment-Host" unless host == "46.225.224.194" && host_key.start_with?("46.225.224.194 ssh-ed25519 ")
  key = ENV.fetch("STAGING_SSH_PRIVATE_KEY")
  raise Ops::ReleaseSupport::Error, "Staging-Leseschlüssel fehlt" if key.strip.empty?
  directory = File.join(ENV.fetch("RUNNER_TEMP"), "production-approval")
  FileUtils.mkdir_p(directory, mode: 0o700)
  key_path = File.join(directory, "read.key")
  File.open(key_path, "w", 0o600) { |file| file.puts key }
  ssh_directory = File.join(Dir.home, ".ssh")
  FileUtils.mkdir_p(ssh_directory, mode: 0o700)
  File.open(File.join(ssh_directory, "known_hosts"), "a", 0o600) { |file| file.puts host_key }
  remote = Ops::DeploymentRemote.new(key_path:)
  refusal = nil
  summary = nil
  production = nil
  Ops::DeployLock.with_lock(host:, key_path:) do
    begin
      approval.validate_current!(manifest:, remote:, project:, mode: selection.fetch(:mode))
      production = remote.running(project:, destination: "hetzner")
      summary = approval.summary(manifest:, production:, mode: selection.fetch(:mode))
    rescue Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error, Ops::DeployImageProof::Error, KeyError, JSON::ParserError => error
      refusal = error
      next
    end
    if ENV.fetch("GITHUB_EVENT_NAME") == "workflow_run"
      begin
        approval.supersede_waiting!(current_run_id: Ops::ReleaseSupport.run_id(ENV.fetch("GITHUB_RUN_ID")))
      rescue Ops::ProductionApproval::Superseded => error
        refusal = error
      end
    end
  end
  raise refusal if refusal
  outputs = selection.merge(commit: manifest.fetch("commit"), digest: manifest.fetch("digest"),
    manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(Ops::ImageFingerprint.canonical(manifest))),
    production_sha256: Digest::SHA256.hexdigest(JSON.generate(Ops::ImageFingerprint.canonical(Ops::ReleaseManifest.image_identity(production)))),
    control_commit: Ops::ReleaseSupport.capture("git", "rev-parse", "HEAD").strip)
  raise Ops::ReleaseSupport::Error, "Kontrollcode ohne gültigen Commit" unless Ops::ReleaseManifest.sha?(outputs.fetch(:control_commit))
  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |file| outputs.each { |key, value| file.puts "#{key}=#{value}" } }
  File.open(ENV.fetch("GITHUB_STEP_SUMMARY"), "a") { |file| file.write(summary) }
rescue KeyError, JSON::ParserError, ArgumentError, Ops::ReleaseSupport::Error, Ops::ReleaseManifest::Error, Ops::DeployLock::Error => error
  warn "Produktionsfreigabe nicht vorbereitet: #{error.message}"
  exit 1
end
