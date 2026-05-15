require "test_helper"

class Backend::ReferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    ReferenceImage.delete_all
    Reference.delete_all
    @admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")
  end

  test "requires authentication" do
    get backend_references_path

    assert_redirected_to new_session_url
  end

  test "renders inbox for authorized user" do
    sign_in_as(@admin)
    create_reference!(title: "KISS")

    get backend_references_path

    assert_response :success
    assert_includes response.body, "Referenzen"
    assert_includes response.body, "KISS"
  end

  test "renders image file metadata for asset backed reference images" do
    sign_in_as(@admin)
    reference = create_reference!(title: "KISS")

    get backend_references_path(reference_id: reference.id, editor_tab: "image")

    assert_response :success
    assert_includes response.body, "01-disgusting-food-museum.jpg"
    assert_includes response.body, "image/jpeg"
    assert_includes response.body, "514 KB"
  end

  test "creates published reference with image metadata" do
    sign_in_as(@admin)

    assert_difference -> { Reference.count }, 1 do
      assert_difference -> { ReferenceImage.count }, 1 do
        post backend_references_path, params: reference_payload(title: "Neue Referenz", status: "published")
      end
    end

    reference = Reference.last
    assert_equal "published", reference.status
    assert_equal "2x1", reference.reference_image.grid_variant
    assert_redirected_to backend_references_path(reference_id: reference.id, status: "published")
  end

  test "updates reference image crop values and hides unpublished references from public page" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Hidden", status: "published")

    patch backend_reference_path(reference), params: reference_payload(title: "Hidden", status: "draft", zoom: "150", focus_x: "30")

    reference.reload
    assert_equal "draft", reference.status
    assert_equal 150.0, reference.reference_image.card_zoom_value
    assert_equal 30.0, reference.reference_image.card_focus_x_value

    get referenzen_path

    assert_response :success
    assert_not_includes response.body, "Hidden"
  end

  test "updates image tab without reference params" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Neil Young", status: "published")

    patch backend_reference_path(reference), params: {
      editor_tab: "image",
      reference_image: {
        alt_text: "NEIL YOUNG",
        sub_text: "",
        grid_variant: "2x2",
        card_focus_x: "47.97521814123377",
        card_focus_y: "54.67037844967532",
        card_zoom: "130"
      }
    }

    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "image")
    reference.reload
    assert_equal "Neil Young", reference.title
    assert_equal "2x2", reference.reference_image.grid_variant
    assert_equal 47.98, reference.reference_image.card_focus_x_value
    assert_equal 54.67, reference.reference_image.card_focus_y_value
    assert_equal 130.0, reference.reference_image.card_zoom_value
  end

  test "uploaded image replaces asset image and renders cache busted url" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Neil Young", status: "published")
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/references/03-neil-young.jpg"),
      "image/jpeg"
    )

    patch backend_reference_path(reference), params: {
      editor_tab: "image",
      reference_image: {
        alt_text: "NEIL YOUNG",
        grid_variant: "2x2",
        card_focus_x: "50",
        card_focus_y: "50",
        card_zoom: "120",
        file: upload
      }
    }

    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "image")
    reference.reload
    assert_nil reference.reference_image.asset_path
    assert_predicate reference.reference_image, :uploaded?
    assert_equal "03-neil-young.jpg", reference.reference_image.filename

    get backend_references_path(reference_id: reference.id, editor_tab: "image")

    assert_response :success
    assert_includes response.body, reference_image_path(reference.reference_image, v: reference.reference_image.updated_at.to_i)
    assert_not_includes response.body, "01-disgusting-food-museum.jpg"
  end

  private
    def create_reference!(title:, status: "published")
      Reference.create!(
        title: title,
        starts_on: Date.new(2026, 5, 1),
        location: "Stuttgart",
        status: status,
        position: 1
      ).tap do |reference|
        reference.create_reference_image!(
          alt_text: title,
          asset_path: "russ_live/references/01-disgusting-food-museum.jpg",
          grid_variant: "1x1"
        )
      end
    end

    def reference_payload(title:, status:, zoom: "110", focus_x: "45")
      {
        reference: {
          title: title,
          starts_on: "2026-05-01",
          location: "Stuttgart",
          production: "SKS Michael Russ",
          description: "Beschreibung",
          status: status,
          position: "1"
        },
        reference_image: {
          alt_text: title,
          sub_text: "Copyright",
          grid_variant: "2x1",
          card_focus_x: focus_x,
          card_focus_y: "55",
          card_zoom: zoom
        }
      }
    end
end
