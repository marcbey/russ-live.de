require "json"

module Ops
  class CompatibilityCopy
    Error = Class.new(StandardError)
    DATABASES = %w[stuttgart_live_de_staging russ_live_de_staging].freeze

    def self.call(connection:, data_path:)
      new(connection:).call(data_path:)
    end

    def initialize(connection:)
      @connection = connection
    end

    def call(data_path:)
      validate_sandbox!
      @connection.transaction do
        tables = @connection.tables - %w[schema_migrations ar_internal_metadata]
        constraints = tables.flat_map do |table|
          @connection.select_all(<<~SQL).map { |row| row.merge("table" => table) }
            SELECT conname, pg_get_constraintdef(oid) AS definition FROM pg_constraint
            WHERE conrelid = #{@connection.quote(@connection.quote_table_name(table))}::regclass AND contype = 'f'
          SQL
        end
        constraints.each { |row| @connection.execute("ALTER TABLE #{qt(row.fetch('table'))} DROP CONSTRAINT #{qt(row.fetch('conname'))}") }
        @connection.execute("TRUNCATE TABLE #{tables.map { |table| qt(table) }.join(', ')} RESTART IDENTITY") unless tables.empty?
        rows = import(data_path, tables)
        constraints.each { |row| @connection.execute("ALTER TABLE #{qt(row.fetch('table'))} ADD CONSTRAINT #{qt(row.fetch('conname'))} #{row.fetch('definition')}") }
        tables.each { |table| @connection.reset_pk_sequence!(table) }
        { "rows" => rows }
      end
    end

    private

    def validate_sandbox!
      valid = DATABASES.include?(@connection.select_value("SELECT current_database()")) &&
        @connection.select_value("SELECT current_setting('live.compatibility_sandbox', true)") == "on"
      raise Error, "Datenkopie benötigt den ausdrücklich isolierten Kompatibilitätsserver" unless valid
    end

    def import(path, target_tables)
      count = 0
      File.open(path) do |file|
        header = JSON.parse(file.readline)
        raise Error, "Datenkopf fehlt" unless header["kind"] == "header" && header["columns"].is_a?(Hash)
        current_table = nil
        batch = []
        flush = lambda do
          next if batch.empty?
          columns = @connection.columns(current_table).reject(&:virtual?).map(&:name) & header.fetch("columns").fetch(current_table)
          raise Error, "Keine gemeinsamen Tabellenspalten" if columns.empty?
          names = columns.map { |name| qt(name) }.join(", ")
          @connection.raw_connection.exec_params("INSERT INTO #{qt(current_table)} (#{names}) SELECT #{names} FROM json_populate_recordset(NULL::#{qt(current_table)}, $1::json)", [ JSON.generate(batch) ])
          count += batch.size
          batch.clear
        end
        file.each_line do |line|
          row = JSON.parse(line)
          table = row.fetch("table")
          next unless target_tables.include?(table)
          if table != current_table
            flush.call
            current_table = table
          end
          raise Error, "Ungültiger Datensatz" unless row["record"].is_a?(Hash)
          batch << row.fetch("record")
          flush.call if batch.size >= 100
        end
        flush.call
      end
      count
    end

    def qt(name)
      @connection.quote_column_name(name)
    end
  end
end
