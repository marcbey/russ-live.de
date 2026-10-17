require "json"
require_relative "deployment_environment"

module StagingReadiness
  Error = Class.new(StandardError)
  DATABASES = { "stuttgart_live_de" => "stuttgart_live_de_staging", "russ_live_de" => "russ_live_de_staging" }.freeze

  def self.verify!(project:, env: ENV, root: "/rails/storage")
    return true unless DeploymentEnvironment.name(env:, rails_env: env.fetch("RAILS_ENV", "development")) == "staging"
    DeploymentEnvironment.validate_runtime!(env:, project:)
    path = File.join(root, ".staging-ready.json")
    raise Error, "Staging benötigt einen abgeschlossenen bereinigten Refresh" unless File.file?(path) && !File.symlink?(path)
    raise Error, "Unsichere Staging-Readiness-Datei" unless (File.stat(path).mode & 0o022).zero? && File.size(path) <= 8192
    marker = JSON.parse(File.read(path))
    valid = marker["schema_version"] == 1 && marker["environment"] == "staging" &&
      marker["volume"] == "stuttgart_live_de_staging_storage" && marker["databases"] == DATABASES &&
      marker["refresh_id"].to_s.match?(/\A[a-z0-9][a-z0-9-]{7,63}\z/)
    raise Error, "Staging-Readiness passt nicht zur Zielzuordnung" unless valid
    true
  rescue JSON::ParserError, Errno::ENOENT
    raise Error, "Staging-Readiness fehlt oder ist ungültig"
  end
end
