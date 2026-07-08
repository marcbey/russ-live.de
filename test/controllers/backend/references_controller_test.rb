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
    assert_includes response.body, 'data-reference-image-crop-preview-tab-param="slider"'
    assert_includes response.body, 'name="reference[title]"'
    assert_includes response.body, 'name="reference[display_date]"'
    assert_includes response.body, 'name="reference[position]"'
    assert_includes response.body, 'name="reference[location]"'
    assert_includes response.body, 'name="reference[tag_list]"'
    assert_includes response.body, 'name="reference[description_en]"'
    assert_includes response.body, 'name="reference_image[grid_variant]"'
    assert_includes response.body, 'name="reference_image[card_zoom]"'
    assert_includes response.body, 'name="reference_slider_image[alt_text]"'
    assert_select ".editor-tabs-actions .button-danger", "Referenz löschen"
    assert_select ".editor-tabs-actions .button-success", "Neue Referenz"
    assert_operator response.body.index("Referenz löschen"), :<, response.body.index("Neue Referenz")
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
    assert_includes response.body, "276 KB"
  end

  test "hides image detail fields until a reference image exists" do
    sign_in_as(@admin)
    reference = Reference.create!(
      title: "Ohne Bild",
      starts_on: Date.new(2026, 5, 1),
      location: "Stuttgart",
      status: "draft",
      position: 1
    )

    get backend_references_path(reference_id: reference.id, editor_tab: "image")

    assert_response :success
    assert_select 'label[for="reference_image_file"]', "Bild"
    assert_select '[data-reference-image-crop-preview-target="imageDependentField"][hidden]', 5
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
    assert_equal 1, reference.position
    assert_equal [ "Open Air", "Clubkonzert" ], reference.tags
    assert_equal "Juni 2025 - März 2026", reference.display_date
    assert_equal "Beschreibung", reference.description
    assert_equal "English description", reference.description_en
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
    assert_equal 1, reference.position
    assert_equal "Noch nicht angegeben", reference.location
    assert_equal "copy", reference.reference_image.sub_text
    assert_equal "1x1", reference.reference_image.grid_variant
    assert_equal 62.77, reference.reference_image.card_focus_x_value
    assert_equal 33.55, reference.reference_image.card_focus_y_value
    assert_equal 280.0, reference.reference_image.card_zoom_value
    assert_equal "03-neil-young.webp", reference.reference_image.filename
    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "image", status: "draft")
  end

  test "accepts manually entered german date format in the single date field" do
    sign_in_as(@admin)

    assert_difference -> { Reference.count }, 1 do
      post backend_references_path, params: {
        reference: {
          title: "Handdatum",
          display_date: "18.05.2026",
          location: "Stuttgart",
          status: "published"
        },
        reference_image: {
          alt_text: "Handdatum",
          grid_variant: "1x1",
          card_focus_x: "50",
          card_focus_y: "50",
          card_zoom: "100"
        }
      }
    end

    assert_equal Date.new(2026, 5, 18), Reference.last.starts_on
    assert_equal "18.05.2026", Reference.last.display_date
  end

  test "creating a reference at an occupied position shifts later references up" do
    sign_in_as(@admin)
    lower = create_reference!(title: "Lower")
    higher = create_reference!(title: "Higher")

    lower.update!(position: 1)
    higher.update!(position: 2)

    assert_difference -> { Reference.count }, 1 do
      post backend_references_path, params: {
        reference: {
          title: "Inserted",
          starts_on_input: "19.05.2026",
          display_date: "Mai 2026",
          location: "Stuttgart",
          status: "published",
          position: 2
        },
        reference_image: {
          alt_text: "Inserted",
          grid_variant: "1x1",
          card_focus_x: "50",
          card_focus_y: "50",
          card_zoom: "100"
        }
      }
    end

    inserted = Reference.find_by!(title: "Inserted")

    assert_equal 1, lower.reload.position
    assert_equal 3, higher.reload.position
    assert_equal 2, inserted.position
  end

  test "destroying a reference closes the position gap" do
    sign_in_as(@admin)
    lower = create_reference!(title: "Lower")
    middle = create_reference!(title: "Middle")
    higher = create_reference!(title: "Higher")

    lower.update!(position: 1)
    middle.update!(position: 2)
    higher.update!(position: 3)

    assert_difference -> { Reference.count }, -1 do
      delete backend_reference_path(middle)
    end

    assert_redirected_to backend_references_path
    assert_equal 1, lower.reload.position
    assert_equal 2, higher.reload.position
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

  test "updates slider tab without reference params" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Neil Young", status: "published")

    patch backend_reference_path(reference), params: {
      editor_tab: "slider",
      reference_slider_image: {
        alt_text: "Slider Alt",
        sub_text: "Slider Copyright"
      }
    }

    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "slider")
    reference.reload
    assert_equal "Neil Young", reference.title
    assert_equal "Slider Alt", reference.reference_image.slider_alt_text
    assert_equal "Slider Copyright", reference.reference_image.slider_sub_text
    assert_nil reference.reference_image.filename
    assert_equal "russ_live/references/01-disgusting-food-museum.jpg", reference.reference_image.asset_path
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
        tag_list: "Open Air\nAusstellung",
        display_date: "Tour 2026"
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
    assert_equal "Tour 2026", reference.display_date
    assert_equal "English description", reference.description_en
    assert_equal "2x2", reference.reference_image.grid_variant
    assert_equal "All Them Witches", reference.reference_image.alt_text
    assert_equal "Travis Shinn", reference.reference_image.sub_text
    assert_equal 62.5, reference.reference_image.card_focus_x_value
    assert_equal 37.5, reference.reference_image.card_focus_y_value
    assert_equal 180.0, reference.reference_image.card_zoom_value

    get backend_references_path(reference_id: reference.id)

    assert_response :success
    assert_includes response.body, 'value="Open Air, Ausstellung"'
    assert_select "textarea[name='reference[description_en]']", "English description"
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
    assert_equal "03-neil-young.webp", reference.reference_image.filename

    get backend_references_path(reference_id: reference.id, editor_tab: "image")

    assert_response :success
    assert_includes response.body, reference_image_path(reference.reference_image, v: reference.reference_image.updated_at.to_i)
    assert_not_includes response.body, "01-disgusting-food-museum.jpg"
  end

  test "uploaded slider image stores separate file and metadata" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Neil Young", status: "published")
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/references/03-neil-young.jpg"),
      "image/jpeg"
    )

    patch backend_reference_path(reference), params: {
      editor_tab: "slider",
      reference_slider_image: {
        alt_text: "Slider Alt",
        sub_text: "Slider Credit",
        file: upload
      }
    }

    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "slider")
    reference.reload
    assert_predicate reference.reference_image, :slider_uploaded?
    assert_equal "Slider Alt", reference.reference_image.slider_alt_text
    assert_equal "Slider Credit", reference.reference_image.slider_sub_text
    assert_equal "03-neil-young.webp", reference.reference_image.slider_filename
    assert_nil reference.reference_image.filename
    assert_equal "russ_live/references/01-disgusting-food-museum.jpg", reference.reference_image.asset_path

    get backend_references_path(reference_id: reference.id, editor_tab: "slider")

    assert_response :success
    assert_includes response.body, "/referenzbilder/#{reference.reference_image.id}"
    assert_includes response.body, "variant=slider"
  end

  test "replacing slider image keeps main reference image intact" do
    sign_in_as(@admin)
    reference = create_reference!(title: "Neil Young", status: "published")
    reference.reference_image.update!(
      slider_file_path: "reference_images/#{reference.reference_image.id}/slider.jpg",
      slider_filename: "old-slider.jpg",
      slider_content_type: "image/jpeg",
      slider_byte_size: 1234
    )
    FileUtils.mkdir_p(Rails.root.join("storage", "reference_images", reference.reference_image.id.to_s))
    File.write(Rails.root.join("storage", reference.reference_image.slider_file_path), "old")

    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/references/03-neil-young.jpg"),
      "image/jpeg"
    )

    patch backend_reference_path(reference), params: {
      editor_tab: "slider",
      reference_slider_image: {
        alt_text: "New Slider Alt",
        file: upload
      }
    }

    assert_redirected_to backend_references_path(reference_id: reference.id, editor_tab: "slider")
    reference.reload
    assert_nil reference.reference_image.filename
    assert_equal "russ_live/references/01-disgusting-food-museum.jpg", reference.reference_image.asset_path
    assert_equal "03-neil-young.webp", reference.reference_image.slider_filename
    assert_equal "New Slider Alt", reference.reference_image.slider_alt_text
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
          starts_on_input: "01.05.2026",
          display_date: "Juni 2025 - März 2026",
          location: "Stuttgart",
          production: "SKS Michael Russ",
          tag_list: "Open Air, Clubkonzert",
          description: "Beschreibung",
          description_en: "English description",
          status: status
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
