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

  test "renders both editor panels in one form with client side tabs" do
    sign_in_as(@admin)
    reference = create_reference!(title: "KISS")

    get backend_references_path(reference_id: reference.id, editor_tab: "image")

    assert_response :success
    assert_includes response.body, 'data-action="reference-image-crop-preview#selectTab"'
    assert_includes response.body, 'data-reference-image-crop-preview-tab-param="reference"'
    assert_includes response.body, 'data-reference-image-crop-preview-tab-param="image"'
    assert_includes response.body, 'name="reference[title]"'
    assert_includes response.body, 'name="reference[location]"'
    assert_includes response.body, 'name="reference[tag_list]"'
    assert_includes response.body, 'name="reference_image[grid_variant]"'
    assert_includes response.body, 'name="reference_image[card_zoom]"'
  end

  test "searches references by tags" do
    sign_in_as(@admin)
    create_reference!(title: "KISS", tag_list: "Open Air")
    create_reference!(title: "Neil Young", tag_list: "Clubkonzert")

    get backend_references_path(query: "open")

    assert_response :success
    assert_includes response.body, "KISS"
    assert_not_includes response.body, "Neil Young"
  end

  test "reference links open with reference tab by default" do
    sign_in_as(@admin)
    reference = create_reference!(title: "KISS")

    get backend_references_path(reference_id: reference.id, editor_tab: "image")

    assert_response :success
    assert_includes response.body, new_backend_reference_path
    assert_includes response.body, backend_references_path(reference_id: reference.id)
    assert_not_includes response.body, new_backend_reference_path(editor_tab: "image")
    assert_not_includes response.body, backend_references_path(reference_id: reference.id, editor_tab: "image")
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
    assert_equal [ "Open Air", "Clubkonzert" ], reference.tags
    assert_equal "2x1", reference.reference_image.grid_variant
    assert_redirected_to backend_references_path(reference_id: reference.id, status: "published")
  end

  test "creates draft reference from image tab without reference params" do
    sign_in_as(@admin)
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/references/03-neil-young.jpg"),
      "image/jpeg"
    )

    assert_difference -> { Reference.count }, 1 do
      assert_difference -> { ReferenceImage.count }, 1 do
        post backend_references_path, params: {
          editor_tab: "image",
          reference_image: {
            alt_text: "my-alt-text",
            sub_text: "copy",
            grid_variant: "1x1",
            card_focus_x: "62.76850544574424",
            card_focus_y: "33.54578323383503",
            card_zoom: "280",
            file: upload
          }
        }
      end
    end

    reference = Reference.last
    assert_equal "draft", reference.status
    assert_equal "my-alt-text", reference.title
    assert_equal Time.zone.today, reference.starts_on
    assert_equal "Noch nicht angegeben", reference.location
    assert_equal "copy", reference.reference_image.sub_text
    assert_equal "1x1", reference.reference_image.grid_variant
    assert_equal 62.77, reference.reference_image.card_focus_x_value
    assert_equal 33.55, reference.reference_image.card_focus_y_value
    assert_equal 280.0, reference.reference_image.card_zoom_value
    assert_equal "03-neil-young.jpg", reference.reference_image.filename
    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "image", status: "draft")
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

  test "updates reference and image params from one save" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Neil Young", status: "draft")

    patch backend_reference_path(reference), params: reference_payload(
      title: "All Them Witches",
      status: "published",
      zoom: "180",
      focus_x: "62.5"
    ).deep_merge(
      editor_tab: "image",
      reference: {
        tag_list: "Open Air\nAusstellung"
      },
      reference_image: {
        alt_text: "All Them Witches",
        sub_text: "Travis Shinn",
        grid_variant: "2x2",
        card_focus_y: "37.5"
      }
    )

    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "image")
    reference.reload
    assert_equal "All Them Witches", reference.title
    assert_equal "published", reference.status
    assert_equal [ "Open Air", "Ausstellung" ], reference.tags
    assert_equal "2x2", reference.reference_image.grid_variant
    assert_equal "All Them Witches", reference.reference_image.alt_text
    assert_equal "Travis Shinn", reference.reference_image.sub_text
    assert_equal 62.5, reference.reference_image.card_focus_x_value
    assert_equal 37.5, reference.reference_image.card_focus_y_value
    assert_equal 180.0, reference.reference_image.card_zoom_value

    get backend_references_path(reference_id: reference.id)

    assert_response :success
    assert_includes response.body, 'value="Open Air, Ausstellung"'
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
    def create_reference!(title:, status: "published", tag_list: nil)
      Reference.create!(
        title: title,
        starts_on: Date.new(2026, 5, 1),
        location: "Stuttgart",
        status: status,
        position: 1,
        tag_list: tag_list
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
          tag_list: "Open Air, Clubkonzert",
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
