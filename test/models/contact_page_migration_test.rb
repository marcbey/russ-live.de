require "test_helper"
require Rails.root.join("db/russ_migrate/20261126120000_update_contact_location_and_directions")

class ContactPageMigrationTest < ActiveSupport::TestCase
  test "updates both languages while preserving drafts and unrelated content" do
    EditablePage.ensure_defaults!
    untouched_page = EditablePage.find_by!(key: "impressum", locale: "de")
    original_attributes = untouched_page.attributes

    %w[de en].each do |locale|
      page = EditablePage.find_by!(key: "kontakt", locale: locale)
      replacements = UpdateContactLocationAndDirections::REPLACEMENTS.fetch(locale)
      old_body = "<p>#{replacements.first.first}</p><p>Directions.#{replacements.last.first}</p>"
      page.update!(
        content: { "body_html" => "#{old_body}<p>Pending editorial addition</p>" },
        published_content: { "body_html" => "#{old_body}<p>Existing contact details</p>" },
        status: "draft"
      )

      migrate_contact_page

      page.reload
      assert_equal "draft", page.status
      assert_includes page.content_value("body_html"), "Pending editorial addition"
      assert_includes page.public_version.content_value("body_html"), "Existing contact details"
      assert_not_includes page.public_version.content_value("body_html"), "Pending editorial addition"
      [ page.content, page.published_content ].each do |content|
        assert_includes content.fetch("body_html"), replacements.first.last
        replacements.each { |old_text, _| assert_not_includes content.fetch("body_html"), old_text }
      end

      updated_attributes = page.attributes
      migrate_contact_page
      assert_equal updated_attributes, page.reload.attributes
    end

    assert_equal original_attributes, untouched_page.reload.attributes
  end

  test "updates legacy fields without replacing custom copy" do
    page = EditablePage.find_or_initialize_by(key: "kontakt", locale: "de")
    page.assign_attributes(
      title: "Kontakt",
      content: { "location" => "Individuelle Ortsbeschreibung", "directions" => "Anreise. Hier geht es zum Fahrplan." },
      published_content: { "location" => "Individuelle Ortsbeschreibung", "directions" => "Anreise. Hier geht es zum Fahrplan." }
    )
    page.save!

    migrate_contact_page

    [ page.reload.content, page.published_content ].each do |content|
      assert_equal "Individuelle Ortsbeschreibung", content.fetch("location")
      assert_equal "Anreise.", content.fetch("directions")
      assert_not content.key?("body_html")
    end
  end

  private
    def migrate_contact_page
      migration = UpdateContactLocationAndDirections.new
      migration.define_singleton_method(:connection) { RussRecord.connection }
      migration.suppress_messages { migration.up }
    end
end
