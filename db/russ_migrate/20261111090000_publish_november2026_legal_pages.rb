require "json"

class PublishNovember2026LegalPages < ActiveRecord::Migration[8.1]
  EDITOR_FIELDS = %w[title content meta_title meta_description].freeze

  def up
    # A fixed snapshot keeps future migrations independent of later template edits.
    pages = JSON.parse(File.read(File.expand_path("../data/legal_pages_20261111.json", __dir__)))

    pages.each do |page|
      existing = connection.select_one(<<~SQL)
        SELECT * FROM editable_pages
        WHERE key = #{connection.quote(page.fetch("key"))}
          AND locale = #{connection.quote(page.fetch("locale"))}
      SQL

      preserve_draft = existing && unpublished_changes?(existing)
      attributes = page.slice("key", "locale")
      attributes.merge!(page.slice(*EDITOR_FIELDS)) unless preserve_draft
      EDITOR_FIELDS.each { |field| attributes["published_#{field}"] = page.fetch(field) }
      attributes["status"] = preserve_draft ? "draft" : "published"

      if existing
        assignments = attributes.map { |name, value| "#{connection.quote_column_name(name)} = #{quote_value(value)}" }
        execute <<~SQL
          UPDATE editable_pages
          SET #{assignments.join(', ')}, published_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
          WHERE id = #{connection.quote(existing.fetch("id"))}
        SQL
      else
        columns = attributes.keys.map { |name| connection.quote_column_name(name) }
        values = attributes.values.map { |value| quote_value(value) }
        execute <<~SQL
          INSERT INTO editable_pages (#{columns.join(', ')}, published_at, created_at, updated_at)
          VALUES (#{values.join(', ')}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Previously published legal copy cannot be reconstructed safely."
  end

  private
    def unpublished_changes?(page)
      return true if page.fetch("status") == "draft" || page["published_at"].nil?

      EDITOR_FIELDS.any? { |field| page[field] != page["published_#{field}"] }
    end

    def quote_value(value)
      connection.quote(value.is_a?(Hash) ? JSON.generate(value) : value)
    end
end
