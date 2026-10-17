# Never mutate the shared Stuttgart connection from Russ.
abort "Nur Staging erlaubt" unless Rails.configuration.x.deployment_environment == "staging"
DeploymentEnvironment.validate_runtime!(project: "russ_live_de")
begin
  counts = Staging::DataSanitizer.call(connection: RussRecord.connection)
  puts "Bereinigte Tabellen: #{counts.size}; gemeinsame Nutzer ausschließlich in Stuttgart bereinigt."
rescue StandardError
  abort "Staging-Bereinigung fehlgeschlagen; keine Datensätze oder Secrets ausgegeben."
end
