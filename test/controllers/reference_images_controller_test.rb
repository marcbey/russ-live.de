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

  test "redirects slider variant to slider asset path" do
    reference = Reference.create!(title: "Konzert", starts_on: Date.new(2026, 5, 1), location: "Stuttgart", status: "published")
    image = reference.create_reference_image!(
      asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
      slider_asset_path: "russ_live/references/03-neil-young.jpg"
    )

    get reference_image_path(image, variant: :slider)

    assert_response :redirect
    assert_includes response.location, "03-neil-young"
  end

  test "serves uploaded slider variant" do
    reference = Reference.create!(title: "Konzert", starts_on: Date.new(2026, 5, 1), location: "Stuttgart", status: "published")
    image = reference.create_reference_image!(asset_path: "russ_live/references/01-disgusting-food-museum.jpg")
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/references/03-neil-young.jpg"),
      "image/jpeg"
    )
    stale_slider_path = Rails.root.join("storage", "reference_images", image.id.to_s, "slider.jpg")
    FileUtils.mkdir_p(stale_slider_path.dirname)
    File.binwrite(stale_slider_path, "stale")
    image.write_uploaded_file!(upload, variant: ReferenceImage::SLIDER_VARIANT)
    image.reload

    get reference_image_path(image, variant: :slider)

    assert_response :success
    assert_equal "image/webp", response.media_type
    assert_equal File.binread(Rails.root.join("storage", image.slider_file_path)), response.body
  end
end
