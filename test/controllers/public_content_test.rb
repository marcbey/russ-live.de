require "test_helper"

class PublicContentTest < ActionDispatch::IntegrationTest
  setup do
    EditablePage.delete_all
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
    ActionText::RichText.delete_all
    EventOffer.delete_all
    EventImage.delete_all
    Event.delete_all
    Venue.delete_all
  end

  %w[de en].each do |locale|
    test "#{locale} contact actions appear before managed copy and location photograph" do
      post locale_path(locale), params: { return_to: kontakt_path }
      page = EditablePage.create!(
        key: "kontakt", locale: locale, title: "Editorial contact",
        content: { "body_html" => "<p>Authored contact information.</p>" }
      )
      page.publish!

      get kontakt_path

      assert_response :success
      assert_select ".contact-quick-actions" do
        assert_select "a[href='tel:+497111635311']", text: /\+49/
        assert_select "a[href='mailto:info@russ-live.de']", text: "info@russ-live.de"
        assert_select "a[href='https://www.vvs.de/verbindungen-und-mobilitaet/fahrplanauskunft']", text: /VVS/
      end
      assert_select "address.rich-copy p", text: "Authored contact information."
      assert_operator response.body.index("contact-quick-actions"), :<, response.body.index("Authored contact information.")
      assert_operator response.body.index("contact-quick-actions"), :<, response.body.index("contact-location-visual")
      assert_equal "<p>Authored contact information.</p>", page.reload.content_value("body_html")
    end

    test "#{locale} contact actions are available with default page content" do
      post locale_path(locale), params: { return_to: kontakt_path }

      get kontakt_path

      assert_response :success
      assert_select ".contact-quick-actions a[href='tel:+497111635311']"
      assert_select ".contact-quick-actions a[href='mailto:info@russ-live.de']"
      assert_select ".contact-quick-actions a[href='https://www.vvs.de/verbindungen-und-mobilitaet/fahrplanauskunft']"
      assert_select "address.rich-copy", text: /Charlottenplatz 17/
      assert_equal 0, EditablePage.count
    end

    test "#{locale} public company and ticketing copy omits draft placeholders" do
      post locale_path(locale), params: { return_to: root_path }

      [ unternehmen_path, root_path, services_path ].each do |path|
        get path

        assert_response :success
        assert_no_match(/Lorem ipsum|Praesent non magna|Aliquam erat volutpat|Maecenas luctus|read-only/i, response.body)
      end
    end

    test "#{locale} press preview starts with the first gallery image and its description" do
      post locale_path(locale), params: { return_to: presse_path }
      create_press_image!

      get press_artist_path("preview-artist")

      assert_response :success
      assert_select "img[src='']", count: 0
      trigger = css_select("[data-press-lightbox-target='trigger']").first
      preview = css_select("[data-press-lightbox-target='image']").first
      assert_equal "Approved press photograph", preview["alt"]
      assert_match %r{\A/rails/active_storage/representations/}, URI.parse(preview["src"]).path
      assert_equal URI.join(request.base_url, trigger["data-lightbox-src"]).to_s, preview["src"]
    end
  end

  private

  def create_press_image!
    venue_id = Venue.insert_all!([
      { name: "Preview Venue", created_at: Time.current, updated_at: Time.current }
    ], returning: %w[id]).rows.first.first
    event_id = Event.insert_all!([
      {
        artist_name: "Preview Artist", normalized_artist_name: "preview artist",
        title: "Preview Tour", slug: "preview-tour", status: "published", venue_id: venue_id,
        published_at: 1.day.ago, start_at: 1.month.from_now, publish_on_russ_live: true,
        created_at: Time.current, updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first
    image_id = EventImage.insert_all!([
      {
        event_id: event_id, purpose: EventImage::PURPOSE_SLIDER,
        alt_text: "Approved press photograph", created_at: Time.current, updated_at: Time.current
      }
    ], returning: %w[id]).rows.first.first
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("press image"), filename: "preview.jpg", content_type: "image/jpeg", service_name: "test"
    )
    ActiveStorage::Attachment.insert_all!([
      { name: "file", record_type: "EventImage", record_id: image_id, blob_id: blob.id, created_at: Time.current }
    ])
  end
end
