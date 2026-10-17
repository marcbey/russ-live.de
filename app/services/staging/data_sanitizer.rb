module Staging
  # Raw SQL intentionally avoids model callbacks, encryption and external clients.
  class DataSanitizer
    Error = Class.new(StandardError)
    DATABASE = "russ_live_de_staging".freeze

    def self.call(connection:)
      new(connection:).call
    end

    def initialize(connection:)
      @connection = connection
    end

    def call
      validate_target!
      @connection.transaction do
        counts = {}
        %w[sessions login_attempts].each { |table| counts[table] = @connection.delete("DELETE FROM #{table}") }
        counts["contacts"] = @connection.update(<<~SQL)
          UPDATE contacts SET name = 'Kontakt ' || id, email = 'contact-' || id || '@example.invalid',
            phone_number = '+49 000 000000', role = 'Staging-Kontakt'
        SQL
        counts["team_members"] = @connection.update("UPDATE team_members SET name = 'Teammitglied ' || id, role = 'Staging-Team', role_en = 'Staging team'")
        %w[contact team_member].each do |type|
          counts["#{type}_images"] = @connection.update("UPDATE #{type}_images SET alt_text = 'Staging', sub_text = NULL, filename = 'staging-image'")
        end
        verify!
        counts
      end
    end

    def verify!
      validate_target!
      checks = [
        "SELECT COUNT(*) FROM sessions", "SELECT COUNT(*) FROM login_attempts",
        "SELECT COUNT(*) FROM contacts WHERE email <> 'contact-' || id || '@example.invalid' OR name <> 'Kontakt ' || id OR phone_number <> '+49 000 000000' OR role <> 'Staging-Kontakt'",
        "SELECT COUNT(*) FROM team_members WHERE name <> 'Teammitglied ' || id OR role IS DISTINCT FROM 'Staging-Team' OR role_en IS DISTINCT FROM 'Staging team'"
      ]
      raise Error, "Bereinigung unvollständig" unless checks.all? { |sql| @connection.select_value(sql).to_i.zero? }
      true
    end

    private

    def validate_target!
      raise Error, "Sanitizer benötigt die eigene Staging-Datenbank" unless @connection.select_value("SELECT current_database()") == DATABASE
    end
  end
end
