require "test_helper"

class ContactImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    RussLiveSchema.ensure!
    ContactImage.delete_all
    Contact.delete_all
  end

  test "redirects asset backed contact image to asset path" do
    contact = Contact.create!(name: "Sebastian Kränzlein", phone_number: "+49", email: "personal@example.com")
    image = contact.create_contact_image!(asset_path: "russ_live/team/sebastian-kraenzlein.jpg")

    get contact_image_path(image)

    assert_response :redirect
    assert_includes response.location, "sebastian-kraenzlein"
  end
end
