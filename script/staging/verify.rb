abort "Nur Staging erlaubt" unless Rails.configuration.x.deployment_environment == "staging"
DeploymentEnvironment.validate_runtime!(project: "russ_live_de")
begin
  Staging::DataSanitizer.new(connection: RussRecord.connection).verify!
  Staging::MediaVerifier.call(connection: RussRecord.connection)
rescue StandardError
  abort "Staging-Kontakt-/Token-/Medienprüfung fehlgeschlagen; keine Datensätze oder Secrets ausgegeben."
end
load Rails.root.join("script/ops/check_staging_acl.rb")
