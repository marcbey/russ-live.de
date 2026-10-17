# Run inside the staging app: bin/rails runner script/ops/check_staging_acl.rb
require "pg"
require_relative "../../app/lib/deployment_environment"

module Ops
  class StagingAclCheck
    Error = Class.new(StandardError)
    DATABASE_SUFFIXES = [ "", "_cache", "_queue", "_cable" ].freeze
    PRODUCTION_DATABASES = %w[stuttgart_live_de russ_live_de].flat_map { |project| DATABASE_SUFFIXES.map { |suffix| "#{project}_production#{suffix}" } }.freeze

    def self.call(project:, env: ENV)
      new(project:, env:).call
    end

    def initialize(project:, env:)
      @project, @env = project, env
    end

    def call
      raise Error, "ACL-Prüfung ist ausschließlich für Staging erlaubt" unless DeploymentEnvironment.name(env: @env, rails_env: "production") == "staging"
      DeploymentEnvironment.validate_runtime!(env: @env, project: @project)
      all_staging = %w[stuttgart_live_de russ_live_de].flat_map { |project| databases(project) }
      roles.each do |role|
        password = @env[role.fetch(:password_key)].to_s
        raise Error, "Pflichtwert fehlt: #{role.fetch(:password_key)}" if password.empty?
        role.fetch(:databases).each do |database|
          connect(role, database, password) do |connection|
            identity = connection.exec("SELECT current_database() AS database, current_user AS username").first
            raise Error, "Verbindung verwendet eine unerwartete Datenbank oder Rolle" unless identity == { "database" => database, "username" => role.fetch(:name) }
            flags = connection.exec("SELECT rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = current_user").first
            raise Error, "Staging-Rolle hat erhöhte Rechte" unless flags.values.all? { |value| value == "f" }
            memberships = connection.exec("SELECT 1 FROM pg_auth_members WHERE member = (SELECT oid FROM pg_roles WHERE rolname = current_user)")
            raise Error, "Staging-Rolle besitzt fremde Rollenmitgliedschaften" unless memberships.ntuples.zero?
            next unless database == role.fetch(:databases).first

            if role[:reader]
              connection.exec("SELECT 1 FROM public.events WHERE FALSE")
              writable = connection.exec("SELECT has_table_privilege(current_user, 'public.events', 'INSERT,UPDATE,DELETE,TRUNCATE') AS writable").first.fetch("writable")
              raise Error, "Staging-Reader hat Schreibrechte" unless writable == "f"
              expect_write_denied(connection)
            else
              table = @project == "stuttgart_live_de" ? "events" : "sessions"
              rollback_query(connection, "UPDATE public.#{table} SET id = id WHERE FALSE")
            end
          end
        end
        denied = PRODUCTION_DATABASES + (all_staging - role.fetch(:databases))
        denied.each { |database| expect_connection_denied(role, database, password) }
      end
      true
    end

    private

    def databases(project)
      DATABASE_SUFFIXES.map { |suffix| "#{project}_staging#{suffix}" }
    end

    def roles
      if @project == "stuttgart_live_de"
        [ { name: "stuttgart_live_de_staging", password_key: "DB_PASSWORD", databases: databases(@project) } ]
      else
        [ { name: "russ_live_de_staging_reader", password_key: "RUSS_LIVE_PRIMARY_DB_PASSWORD", databases: [ "stuttgart_live_de_staging" ], reader: true },
          { name: "russ_live_de_staging", password_key: "RUSS_LIVE_OPERATIONAL_DB_PASSWORD", databases: databases(@project) } ]
      end
    end

    def connect(role, database, password)
      PG.connect(host: @env.fetch("DB_HOST"), port: Integer(@env.fetch("DB_PORT")), dbname: database,
        user: role.fetch(:name), password:, connect_timeout: 5) { |connection| yield connection }
    end

    def expect_connection_denied(role, database, password)
      connected = false
      begin
        connect(role, database, password) { connected = true }
      rescue PG::ConnectionBad, PG::InsufficientPrivilege => error
        state = error.result&.error_field(PG::Result::PG_DIAG_SQLSTATE)
        expected = %w[28000 42501].include?(state) || error.message.match?(/pg_hba.conf (rejects connection|entry)|permission denied for database/)
        raise Error, "Negativprüfung endete ohne belegte Zugriffsverweigerung" unless expected
        return
      end
      raise Error, "Staging-Rolle kann eine fremde Datenbank öffnen" if connected
    end

    def expect_write_denied(connection)
      denied = false
      begin
        rollback_query(connection, "UPDATE public.events SET id = id WHERE FALSE")
      rescue PG::InsufficientPrivilege, PG::ReadOnlySqlTransaction
        denied = true
      end
      raise Error, "Staging-Reader kann schreiben" unless denied
    end

    def rollback_query(connection, query)
      connection.exec("BEGIN")
      begin
        connection.exec(query)
      ensure
        connection.exec("ROLLBACK")
      end
    end
  end
end

project = case Rails.application.class.name.split("::").first
when "StuttgartLiveDe" then "stuttgart_live_de"
when "RussLive" then "russ_live_de"
else abort "Unbekanntes Projekt für ACL-Prüfung"
end
begin
  Ops::StagingAclCheck.call(project:)
  puts "Staging-ACL geprüft: eigene Datenbanken erreichbar, Reader ohne Schreibrechte, fremde Datenbanken gesperrt."
rescue Ops::StagingAclCheck::Error, DeploymentEnvironment::ConfigurationError, PG::Error
  warn "Staging-ACL-Prüfung fehlgeschlagen; keine Datensätze oder Secrets ausgegeben."
  exit 1
end
