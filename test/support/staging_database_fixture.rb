require "open3"
require "json"
require "pg"
require "securerandom"
require "timeout"

class StagingFixtureRecord < ActiveRecord::Base
  self.abstract_class = true
end

# A disposable real PostgreSQL cluster: never connects to a developer or server DB.
module StagingDatabaseFixture
  def open_staging_fixture(database:, schema:)
    @fixture_container = "staging-sanitizer-#{SecureRandom.hex(8)}"
    docker!("run", "--detach", "--rm", "--name", @fixture_container,
      "--publish", "127.0.0.1::5432", "--env", "POSTGRES_HOST_AUTH_METHOD=trust", "postgres:16.15")
    info = JSON.parse(docker!("inspect", @fixture_container)).first
    port = info.fetch("NetworkSettings").fetch("Ports").fetch("5432/tcp").first.fetch("HostPort")
    config = { adapter: "postgresql", host: "127.0.0.1", port:, username: "postgres", database: }
    Timeout.timeout(30) do
      loop do
        begin
          PG.connect(host: config[:host], port:, user: "postgres", dbname: "postgres") do |pg|
            pg.exec("CREATE DATABASE #{PG::Connection.quote_ident(database)}")
          end
          break
        rescue PG::ConnectionBad
          sleep 0.1
        end
      end
    end
    StagingFixtureRecord.establish_connection(config)
    @stage = StagingFixtureRecord.connection
    script = <<~RUBY
      require "active_record"
      require "json"
      ActiveRecord::Base.establish_connection(JSON.parse(ENV.fetch("STAGING_FIXTURE_CONNECTION")))
      ActiveRecord::Migration.verbose = false
      load ARGV.fetch(0)
    RUBY
    _, err, status = Open3.capture3({ "STAGING_FIXTURE_CONNECTION" => config.to_json },
      "mise", "exec", "--", "bundle", "exec", "ruby", "-e", script, schema.to_s)
    raise "Fixture schema failed: #{err}" unless status.success?
  rescue Exception
    close_staging_fixture
    raise
  end

  def close_staging_fixture
    StagingFixtureRecord.remove_connection
    Open3.capture3("docker", "rm", "--force", @fixture_container) if @fixture_container
  end

  def insert_stage(table, attributes)
    types = @stage.columns(table).index_by(&:name)
    columns = types.keys
    now = Time.utc(2026, 1, 1)
    attributes = { created_at: now, updated_at: now }.select { |key, _| columns.include?(key.to_s) }.merge(attributes)
    names = attributes.keys.map { |key| @stage.quote_column_name(key) }.join(", ")
    values = attributes.map { |key, value| @stage.quote([ :json, :jsonb ].include?(types.fetch(key.to_s).type) ? value.to_json : value) }.join(", ")
    @stage.select_value("INSERT INTO #{@stage.quote_table_name(table)} (#{names}) VALUES (#{values}) RETURNING id")
  end

  def stage_row(table, id)
    @stage.select_one("SELECT * FROM #{@stage.quote_table_name(table)} WHERE id = #{Integer(id)}")
  end

  def stage_count(table)
    @stage.select_value("SELECT COUNT(*) FROM #{@stage.quote_table_name(table)}").to_i
  end

  def docker!(*args)
    out, err, status = Open3.capture3("docker", *args)
    raise "Disposable PostgreSQL fixture failed: #{err}" unless status.success?
    out
  end
end
