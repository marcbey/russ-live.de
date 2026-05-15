require "test_helper"

class Backend::ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    JobImage.delete_all
    Job.delete_all
    ContactImage.delete_all
    Contact.delete_all
    @admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")
  end

  test "requires authentication" do
    get backend_contacts_path

    assert_redirected_to new_session_url
  end

  test "renders inbox with backend navigation" do
    sign_in_as(@admin)
    create_contact!(name: "Sebastian Kränzlein")

    get backend_contacts_path

    assert_response :success
    assert_includes response.body, "Ansprechpartner"
    assert_includes response.body, "Referenzen"
    assert_includes response.body, "Jobs"
    assert_includes response.body, "Logout"
    assert_includes response.body, "Sebastian Kränzlein"
    assert_select ".editor-tabs-actions .button-danger", "Ansprechpartner löschen"
    assert_select ".editor-tabs-actions .button-success", "Neuer Ansprechpartner"
    assert_operator response.body.index("Ansprechpartner löschen"), :<, response.body.index("Neuer Ansprechpartner")
  end

  test "image tab does not expose alt text or copyright fields" do
    sign_in_as(@admin)
    contact = create_contact!(name: "Sebastian Kränzlein")

    get backend_contacts_path(contact_id: contact.id, editor_tab: "image")

    assert_response :success
    assert_includes response.body, 'name="contact_image[file]"'
    assert_not_includes response.body, 'name="contact_image[alt_text]"'
    assert_not_includes response.body, 'name="contact_image[sub_text]"'
  end

  test "searches contacts by phone and email" do
    sign_in_as(@admin)
    create_contact!(name: "Sebastian Kränzlein", phone_number: "+49.711.16 353 42", email: "sebastian@example.com")
    create_contact!(name: "Andere Person", phone_number: "+49.711.10", email: "andere@example.com")

    get backend_contacts_path(query: "353")

    assert_response :success
    assert_includes response.body, "Sebastian Kränzlein"
    assert_not_includes response.body, "Andere Person"
  end

  test "creates contact with image metadata" do
    sign_in_as(@admin)

    assert_difference -> { Contact.count }, 1 do
      assert_difference -> { ContactImage.count }, 1 do
        post backend_contacts_path, params: contact_payload(name: "Neue Person")
      end
    end

    contact = Contact.last
    assert_equal "Neue Person", contact.name
    assert_equal "+497111", contact.tel_href
    assert_equal "Neue Person", contact.contact_image.alt_text
    assert_nil contact.contact_image.sub_text
    assert_redirected_to backend_contacts_path(contact_id: contact.id)
  end

  test "does not delete contact referenced by jobs" do
    sign_in_as(@admin)
    contact = create_contact!(name: "Sebastian Kränzlein")
    Job.create!(contact: contact, title: "Stagehands", slug: "stagehands", location: "Stuttgart", status: "published")

    assert_no_difference -> { Contact.count } do
      delete backend_contact_path(contact)
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "solange Jobs ihn verwenden"
  end

  private
    def create_contact!(name:, phone_number: "+49.711.16 353 42", email: "personal@example.com")
      Contact.create!(name: name, role: "Personal", phone_number: phone_number, email: email, position: 1).tap do |contact|
        contact.create_contact_image!(asset_path: "russ_live/team/sebastian-kraenzlein.jpg", alt_text: name)
      end
    end

    def contact_payload(name:)
      {
        contact: {
          name: name,
          role: "Personal",
          phone_number: "+49 711 1",
          email: "neu@example.com",
          position: "1"
        },
        contact_image: {}
      }
    end
end
