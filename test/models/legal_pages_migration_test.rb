require "test_helper"
require Rails.root.join("db/russ_migrate/20261111090000_publish_november2026_legal_pages")

class LegalPagesMigrationTest < ActiveSupport::TestCase
  setup do
    EditablePage.delete_all
  end

  test "publishes supplied legal pages in both languages without changing other pages" do
    EditablePage.ensure_defaults!
    legal = EditablePage.find_by!(key: "datenschutz", locale: "de")
    legal.update!(content: { "body_html" => "<p>Old published privacy notice</p>" })
    legal.publish!
    contact = EditablePage.find_by!(key: "kontakt", locale: "de")
    original_contact = contact.attributes

    migrate_legal_pages

    assert_equal original_contact, contact.reload.attributes
    assert_equal "published", legal.reload.status
    assert_equal legal.content, legal.published_content
    assert_includes legal.content_value("body_html"), "Hetzner Online GmbH"
    assert_not_includes legal.content_value("body_html"), "Old published privacy notice"

    %w[de en].each do |locale|
      %w[impressum datenschutz bewerber_datenschutz].each do |key|
        page = EditablePage.find_by!(key: key, locale: locale)
        assert_equal EditablePage.default_for(key, locale).content, page.published_content
        assert page.published_at.present?
      end
    end
  end

  test "creates missing pages and preserves existing unpublished drafts" do
    draft = EditablePage.create!(
      key: "datenschutz", locale: "de", title: "Unpublished title",
      content: { "body_html" => "<p>Unpublished notes</p>" }, status: "draft"
    )
    previous_draft = draft.attributes.slice("title", "content", "meta_title", "meta_description")

    migrate_legal_pages

    assert_equal 6, EditablePage.count
    assert_equal previous_draft, draft.reload.attributes.slice(*previous_draft.keys)
    assert_equal "draft", draft.status
    assert_includes draft.public_version.content_value("body_html"), "Hetzner Online GmbH"
    assert_not_includes draft.public_version.content_value("body_html"), "Unpublished notes"
  end

  test "preserves pending changes to an already published page" do
    EditablePage.ensure_defaults!
    page = EditablePage.find_by!(key: "impressum", locale: "de")
    page.update!(content: { "body_html" => "<p>Pending editorial changes</p>" }, status: "draft")

    migrate_legal_pages

    assert_equal "<p>Pending editorial changes</p>", page.reload.content_value("body_html")
    assert_equal "draft", page.status
    assert_includes page.public_version.content_value("body_html"), "HRB 23472"
  end

  private
    def migrate_legal_pages
      migration = PublishNovember2026LegalPages.new
      migration.define_singleton_method(:connection) { RussRecord.connection }
      migration.suppress_messages { migration.up }
    end
end
