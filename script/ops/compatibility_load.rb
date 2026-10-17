# Run as standalone pinned Ruby inside the disconnected compatibility daemon.
require "active_record"
require "json"
require "bcrypt"
require_relative "compatibility_copy"

input = JSON.parse(File.read("/probe/input.json"))
project = ARGV.fetch(0)
abort "Unbekanntes Probeprojekt" unless %w[stuttgart_live_de russ_live_de].include?(project)
settings = input.fetch("apps").fetch(project)
database = "#{project}_staging"
ActiveRecord::Base.establish_connection(adapter: "postgresql", host: "172.18.0.1", port: 5432, database:,
  username: "postgres", password: input.fetch("postgres_password"))
connection = ActiveRecord::Base.connection
abort "Kein isolierter Prüfserver" unless connection.select_value("SELECT current_setting('live.compatibility_sandbox', true)") == "on"
header = JSON.parse(File.open(settings.fetch("schema_path"), &:readline))
abort "Schema gehört zu anderer App" unless header["project"] == project && header["kind"] == "header"
ActiveRecord::Migration.verbose = false
eval(header.fetch("schema"), TOPLEVEL_BINDING, "trusted-app-schema.rb")
versions = header.fetch("versions")
abort "Ungültige Schemaversionen" unless versions.all? { |version| version.match?(/\A[0-9]{14}\z/) }
connection.execute("DELETE FROM schema_migrations")
versions.each { |version| connection.execute("INSERT INTO schema_migrations (version) VALUES (#{connection.quote(version)})") }
Ops::CompatibilityCopy.call(connection:, data_path: settings.fetch("data_path"))

if project == "stuttgart_live_de"
  digest = BCrypt::Password.create(input.fetch("admin_password"), cost: BCrypt::Engine::MIN_COST).to_s
  connection.execute(<<~SQL)
    INSERT INTO users (email_address, name, role, password_digest, created_at, updated_at)
    VALUES ('probe-admin@example.invalid', 'Probe Admin', 'admin', #{connection.quote(digest)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
  SQL
end

# Assign only this private server's fixed staging owners; no production roles exist.
owner = connection.quote_column_name("#{project}_staging")
connection.tables.each { |table| connection.execute("ALTER TABLE #{connection.quote_table_name(table)} OWNER TO #{owner}") }
connection.select_values("SELECT relname FROM pg_class WHERE relkind = 'S' AND relnamespace = 'public'::regnamespace").each do |sequence|
  connection.execute("ALTER SEQUENCE #{connection.quote_table_name(sequence)} OWNER TO #{owner}")
end
connection.execute("ALTER SCHEMA public OWNER TO #{owner}")
connection.execute("GRANT ALL ON SCHEMA public TO #{owner}")
if project == "stuttgart_live_de"
  connection.execute("GRANT USAGE ON SCHEMA public TO russ_live_de_staging_reader")
  connection.execute("GRANT SELECT ON ALL TABLES IN SCHEMA public TO russ_live_de_staging_reader")
end
