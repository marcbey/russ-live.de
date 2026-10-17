# Standalone pinned Ruby inside the existing container; never boots the Rails app.
require "active_record"
require "json"
require "stringio"
require "bcrypt"
require "securerandom"

abort "Unbekanntes Exportprojekt" unless %w[stuttgart_live_de russ_live_de].include?(PROJECT)
abort "Unbekannter Exportmodus" unless %w[data schema].include?(EXPORT_MODE)
abort "Datenbank-URLs werden für diesen Export nicht ausgewertet" if ENV.keys.any? { |key| key == "DATABASE_URL" || key.end_with?("_DATABASE_URL") }
suffix = EXPORT_MODE == "data" ? "staging" : "production"
if EXPORT_MODE == "data"
  abort "Datenexport ist ausschließlich für bereites Staging erlaubt" unless ENV["APP_ENVIRONMENT"] == "staging" && ENV["RAILS_ENV"] == "production"
  require File.join(Dir.pwd, "app/lib/staging_readiness")
  StagingReadiness.verify!(project: PROJECT)
end
database = ENV.fetch(PROJECT == "stuttgart_live_de" ? "DB_NAME" : "RUSS_DB_NAME", "#{PROJECT}_production")
username = ENV.fetch(PROJECT == "stuttgart_live_de" ? "DB_USER" : "OPERATIONAL_DB_USER", PROJECT)
password = PROJECT == "stuttgart_live_de" ? ENV["DB_PASSWORD"] || ENV["STUTTGART_LIVE_DE_DATABASE_PASSWORD"] : ENV["RUSS_LIVE_OPERATIONAL_DB_PASSWORD"]
abort "Export-Ziel ist nicht die eigene erwartete Datenbank" unless database == "#{PROJECT}_#{suffix}" && password && !password.empty?
ActiveRecord::Base.establish_connection(adapter: "postgresql", host: ENV.fetch("DB_HOST", "127.0.0.1"), port: Integer(ENV.fetch("DB_PORT", "5432")),
  database:, username:, password:, variables: { default_transaction_read_only: "on" })
connection = ActiveRecord::Base.connection
abort "Falsche tatsächliche Exportdatenbank" unless connection.select_value("SELECT current_database()") == "#{PROJECT}_#{suffix}"

excluded = %w[schema_migrations ar_internal_metadata sessions login_attempts newsletter_subscribers newsletter_consent_events
  newsletter_subscriber_interests publish_attempts event_social_posts social_connections social_connection_targets
  raw_event_imports import_run_errors import_event_images event_change_logs]
tables = (connection.tables - excluded).sort
fresh_digest = BCrypt::Password.create(SecureRandom.hex(32), cost: BCrypt::Engine::MIN_COST).to_s
connection.transaction do
  connection.execute("SET TRANSACTION READ ONLY")
  io = StringIO.new
  ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, io)
  versions = connection.select_values("SELECT version FROM schema_migrations ORDER BY version")
  columns = tables.to_h { |table| [ table, connection.columns(table).map(&:name) ] }
  puts JSON.generate(kind: "header", project: PROJECT, database: "#{PROJECT}_#{suffix}", schema: io.string, versions:, columns:)
  if EXPORT_MODE == "data"
    tables.each do |table|
      masks = case table
      when "users"
        "jsonb_build_object('email_address', 'user-' || t.id || '@example.invalid', 'name', 'Benutzer ' || t.id, 'role', 'editor', 'password_digest', #{connection.quote(fresh_digest)}, 'failed_login_attempts', 0, 'locked_until', NULL, 'last_failed_login_at', NULL)"
      when "events" then "jsonb_build_object('editor_notes', NULL, 'source_snapshot', '{}'::jsonb)"
      when "event_llm_enrichments" then "jsonb_build_object('raw_response', '{}'::jsonb)"
      when "import_runs" then "jsonb_build_object('metadata', '{}'::jsonb, 'error_message', NULL)"
      when "import_sources" then "jsonb_build_object('settings', '{}'::jsonb, 'active', false)"
      when "import_source_configs" then "jsonb_build_object('settings', '{}'::jsonb)"
      when "blog_posts" then "jsonb_build_object('author_name', 'Redaktion Staging')"
      when "legacy_redirects" then "jsonb_build_object('source_metadata', '{}'::jsonb)"
      when "active_storage_blobs" then "jsonb_build_object('filename', 'asset-' || t.id, 'metadata', '{}'::text, 'service_name', 'local')"
      when "newsletter_interests" then "jsonb_build_object('mailjet_segment_id', NULL)"
      when "newsletter_issues"
        "jsonb_build_object('title', 'Staging', 'subject', 'Staging', 'intro', NULL, 'team_tip_name', NULL, 'team_tip_text', NULL, 'team_tip_role', NULL, 'team_tip_image_url', NULL, 'team_tip_profile_key', NULL, 'mailjet_campaign_id', NULL, 'mailjet_campaign_draft_id', NULL, 'mailjet_error_message', NULL)"
      when "contacts" then "jsonb_build_object('name', 'Kontakt ' || t.id, 'email', 'contact-' || t.id || '@example.invalid', 'phone_number', '+49 000 000000', 'role', 'Staging')"
      when "team_members" then "jsonb_build_object('name', 'Teammitglied ' || t.id, 'role', 'Staging', 'role_en', 'Staging')"
      when "contact_images", "team_member_images" then "jsonb_build_object('alt_text', 'Staging', 'sub_text', NULL, 'filename', 'staging')"
      else "'{}'::jsonb"
      end
      expression = "to_jsonb(t) || #{masks}"
      where = case table
      when "active_storage_attachments" then " WHERE record_type <> 'EventSocialPost'"
      when "app_settings"
        " WHERE key IN ('sks_promoter_ids','sks_organizer_notes','homepage_genre_lane_slugs','homepage_genre_tag_cloud_enabled','homepage_highlight_video','venue_duplicate_mappings')"
      else ""
      end
      # Cursor batches avoid copying complete production-sized datasets into memory.
      query = "SELECT jsonb_build_object('table', #{connection.quote(table)}, 'record', #{expression}) AS line FROM #{connection.quote_table_name(table)} t#{where}"
      pg = connection.raw_connection
      pg.exec("DECLARE compatibility_rows NO SCROLL CURSOR FOR #{query}")
      loop do
        batch = pg.exec("FETCH FORWARD 500 FROM compatibility_rows")
        break if batch.ntuples.zero?
        batch.each { |row| STDOUT.puts(row.fetch("line")) }
      end
      pg.exec("CLOSE compatibility_rows")
    end
  end
end
