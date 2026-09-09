require "test_helper"

class Backend::PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    EditablePage.delete_all
    @admin = create_stuttgart_user!(email_address: "admin@russ-live.de", role: "admin")
  end

  test "requires authentication" do
    get backend_pages_path

    assert_redirected_to new_session_url
  end

  test "renders editor with default editable pages" do
    sign_in_as(@admin)

    get backend_pages_path

    assert_response :success
    assert_equal 10, EditablePage.count
    assert_includes response.body, "Kontakt"
    assert_includes response.body, "Impressum"
    assert_includes response.body, "Datenschutz"
    assert_includes response.body, "AGB"
    assert_includes response.body, "Jugendschutz"
    assert_includes response.body, "Kontakttext"
    assert_not_includes response.body, "Intro Standort"
    assert_includes response.body, "Veröffentlichen"
    assert_includes response.body, "Vorschau anzeigen"
  end

  test "saves draft without changing published content" do
    sign_in_as(@admin)
    EditablePage.ensure_defaults!
    page = EditablePage.find_by!(key: "kontakt", locale: "de")

    patch backend_page_path(page), params: page_payload(
      title: "Kontakt Entwurf",
      content: { body_html: "<p>Nur im Entwurf sichtbar</p>" }
    )

    assert_redirected_to backend_pages_path(page_id: page.id)
    page.reload
    assert_equal "draft", page.status
    assert_equal "Kontakt Entwurf", page.title
    assert_equal "<p>Nur im Entwurf sichtbar</p>", page.content_value("body_html")

    get kontakt_path

    assert_response :success
    assert_not_includes response.body, "Nur im Entwurf sichtbar"
  end

  test "publishes page content" do
    sign_in_as(@admin)
    EditablePage.ensure_defaults!
    page = EditablePage.find_by!(key: "kontakt", locale: "de")

    patch backend_page_path(page), params: page_payload(
      title: "Kontakt Neu",
      content: { body_html: "<p>Jetzt live sichtbar</p>" },
      publish_page: "1"
    )

    assert_redirected_to backend_pages_path(page_id: page.id)
    page.reload
    assert_equal "published", page.status
    assert_equal "Kontakt Neu", page.published_title
    assert_equal "<p>Jetzt live sichtbar</p>", page.published_content.fetch("body_html")

    get kontakt_path

    assert_response :success
    assert_includes response.body, "Kontakt Neu"
    assert_includes response.body, "Jetzt live sichtbar"
  end

  test "previews draft content" do
    sign_in_as(@admin)
    EditablePage.ensure_defaults!
    page = EditablePage.find_by!(key: "impressum", locale: "de")
    page.update!(
      title: "Impressum Vorschau",
      content: { "body_html" => "<p>Vorschau-Inhalt</p>" },
      status: "draft"
    )

    get preview_backend_page_path(page)

    assert_response :success
    assert_includes response.body, "Impressum Vorschau"
    assert_includes response.body, "Vorschau-Inhalt"
  end

  test "edits only youth protection copy text" do
    sign_in_as(@admin)
    EditablePage.ensure_defaults!
    page = EditablePage.find_by!(key: "jugendschutz", locale: "de")

    get backend_pages_path(page_id: page.id)

    assert_response :success
    assert_includes response.body, "Text links"
    assert_includes response.body, "Viele Menschen"
    assert_not_includes response.body, "legal-youth-layout"
    assert_not_includes response.body, "data-action=&quot;legal-print#print&quot;"
  end

  private
    def page_payload(title:, content:, publish_page: nil)
      {
        editable_page: {
          title: title,
          meta_title: "#{title} | Russ Live",
          meta_description: "Beschreibung",
          content: content
        },
        publish_page: publish_page
      }.compact
    end
end
