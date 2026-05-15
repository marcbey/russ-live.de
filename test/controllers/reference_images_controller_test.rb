require "test_helper"

class ReferenceImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    RussLiveSchema.ensure!
    ReferenceImage.delete_all
    Reference.delete_all
  end

  test "redirects asset backed reference image to asset path" do
    reference = Reference.create!(title: "Konzert", starts_on: Date.new(2026, 5, 1), location: "Stuttgart", status: "published")
    image = reference.create_reference_image!(asset_path: "russ_live/references/01-disgusting-food-museum.jpg")

    get reference_image_path(image)

    assert_response :redirect
    assert_includes response.location, "01-disgusting-food-museum"
  end
end
