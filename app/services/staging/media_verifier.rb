require "pathname"

module Staging
  class MediaVerifier
    Error = Class.new(StandardError)
    FIELDS = { "contact_images" => %w[file_path], "team_member_images" => %w[file_path],
      "job_images" => %w[file_path], "reference_images" => %w[file_path slider_file_path slider_mobile_file_path] }.freeze

    def self.call(connection:, root: "/rails/storage")
      raise Error, "Medienprüfung benötigt die eigene Staging-Datenbank" unless connection.select_value("SELECT current_database()") == DataSanitizer::DATABASE
      base = Pathname.new(root).realpath
      FIELDS.each do |table, fields|
        connection.select_all("SELECT #{fields.join(', ')} FROM #{table}").each do |row|
          row.values.compact_blank.each do |relative|
            path = Pathname.new(relative)
            raise Error, "Ungültiger Medienpfad" if path.absolute? || path.each_filename.include?("..")
            file = base.join(path).realpath
            raise Error, "Medium liegt außerhalb von Staging" unless file.file? && file.to_s.start_with?("#{base}/")
          end
        end
      end
      true
    rescue Errno::ENOENT, Errno::EACCES
      raise Error, "Referenzierte Mediendatei fehlt oder ist nicht lesbar"
    end
  end
end
