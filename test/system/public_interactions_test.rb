require "application_system_test_case"

class PublicInteractionsTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1440, 1000)
  end

  test "reference details toggle with Enter and Space while keeping keyboard focus" do
    create_reference!
    visit referenzen_path

    button = find(".reference-card-flip[aria-label*='KEYBOARD REFERENCE']")
    button.send_keys(:enter)
    assert_equal "true", button["aria-pressed"]
    assert_selector ".reference-card-flip:focus"
    button.send_keys(:space)
    assert_equal "false", button["aria-pressed"]
    assert_selector ".reference-card-flip:focus"
  end

  test "classic reference slider details support the nested button keyboard activation" do
    reference = create_reference!
    visit referenzen_path
    # The legacy slider is a reusable partial; mount its real markup with the public assets.
    html = ApplicationController.render(partial: "pages/reference_slider", locals: { references: [ reference ], flip_enabled: true })
    page.execute_script("document.querySelector('main').innerHTML = arguments[0]", html)

    button = find(".klassik-slide-flip-button")
    button.send_keys(:enter)
    assert_equal "true", button["aria-pressed"]
    assert_selector ".klassik-slide-flip-button:focus"
    button.send_keys(:space)
    assert_equal "false", button["aria-pressed"]
    assert_selector ".klassik-slide-flip-button:focus"
  end

  test "skip link transfers focus and fragment to main content" do
    visit kontakt_path
    find(".skip-link", visible: :all).send_keys(:enter)

    assert_selector "main#main-content:focus"
    assert_equal "main-content", URI.parse(page.current_url).fragment
  end

  test "mobile navigation contains keyboard focus and restores page state on Escape and resize" do
    page.current_window.resize_to(390, 844)
    visit kontakt_path
    opener = find(".mobile-menu-button")
    opener.send_keys(:enter)

    assert_selector ".main-nav a:focus"
    assert page.evaluate_script("document.querySelector('main').inert")
    24.times do
      page.driver.browser.action.send_keys(:tab).perform
      assert page.evaluate_script("document.activeElement.closest('.main-nav, .mobile-menu-button') !== null")
    end
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector ".mobile-menu-button:focus[aria-expanded='false']"
    assert_not page.evaluate_script("document.querySelector('main').inert")

    opener.click
    page.current_window.resize_to(1440, 1000)
    assert_selector ".mobile-menu-button[aria-expanded='false']", visible: :all
    assert_not page.evaluate_script("document.querySelector('main').inert")
    assert_not_equal "hidden", page.evaluate_script("document.body.style.overflow")
  end

  test "mobile navigation releases the page before Turbo caches it" do
    page.current_window.resize_to(390, 844)
    visit kontakt_path
    find(".mobile-menu-button").click
    assert page.evaluate_script("document.querySelector('main').inert")

    page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
    assert_selector ".mobile-menu-button[aria-expanded='false']", visible: :all
    assert_not page.evaluate_script("document.querySelector('main').inert")
    assert_not_equal "hidden", page.evaluate_script("document.body.style.overflow")
  end

  test "desktop submenu Escape closes the focused submenu until focus leaves" do
    visit kontakt_path
    company = find(".has-submenu", match: :first)
    company.find("a", match: :first).send_keys(:tab)
    assert_selector "#company-submenu a:focus"
    page.driver.browser.action.send_keys(:escape).perform

    assert_selector ".has-submenu > a:focus"
    assert_selector "#company-submenu", style: { opacity: "0" }, visible: :all
    assert page.evaluate_script("document.querySelector('#company-submenu').inert")
  end

  test "press dialog traps Tab in both directions and restores the gallery trigger" do
    create_press_event!
    visit press_artist_path("keyboard-artist")
    trigger = find("[data-press-lightbox-target='trigger']", match: :first)
    trigger.click
    assert_selector ".press-lightbox-close:focus"

    page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    assert_selector ".press-lightbox-next:focus"
    8.times do
      page.driver.browser.action.send_keys(:tab).perform
      assert page.evaluate_script("document.activeElement.closest('[role=dialog]') !== null")
    end
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "[data-press-lightbox-target='trigger']:focus"
    assert_selector ".press-lightbox[hidden]", visible: :all
  end

  test "public section scrolling honors reduced motion" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit root_path
    page.execute_script(<<~JS)
      window.recordedScrolls = [];
      const originalScroll = window.scrollTo.bind(window);
      window.scrollTo = options => { window.recordedScrolls.push(options); originalScroll(options); };
    JS
    find(".home-hero-button").click

    assert_equal "auto", page.evaluate_script("window.recordedScrolls.at(-1).behavior")
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "narrow screens keep service contacts youth fields and menu start inside the viewport" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 844, deviceScaleFactor: 1, mobile: false)
    visit services_path
    assert_equal 320, page.evaluate_script("window.innerWidth")
    assert_selector ".service-contact-meta a[href^='mailto:']", minimum: 1
    assert page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.service-contact-meta a[href^="mailto:"]')].every(link => {
        const text = document.createRange();
        text.selectNodeContents(link);
        return [...text.getClientRects()].every(rect => rect.left >= 0 && rect.right <= innerWidth);
      })
    JS

    visit jugendschutz_path
    assert_selector ".legal-youth-form input", minimum: 1
    assert page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.legal-youth-form input, .legal-youth-form')].every(element => {
        const rect = element.getBoundingClientRect();
        return rect.left >= 0 && rect.right <= innerWidth;
      })
    JS
    find(".mobile-menu-button").click
    assert_selector ".main-nav a:focus"
    assert page.evaluate_script(<<~JS)
      (() => {
        const nav = document.querySelector('.main-nav');
        const firstLink = nav.querySelector('a').getBoundingClientRect();
        return firstLink.top >= nav.getBoundingClientRect().top && firstLink.bottom <= innerHeight;
      })()
    JS
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def create_reference!
    Reference.create!(title: "KEYBOARD REFERENCE", starts_on: Date.new(2026, 5, 1), location: "Stuttgart", status: "published", position: 1).tap do |reference|
      reference.create_reference_image!(asset_path: "russ_live/references/01-disgusting-food-museum.jpg", alt_text: reference.title)
    end
  end

  def create_press_event!
    venue_id = Venue.insert_all!([ { name: "Keyboard venue", created_at: Time.current, updated_at: Time.current } ], returning: %w[id]).rows.first.first
    event_id = Event.insert_all!([ {
      artist_name: "Keyboard Artist", normalized_artist_name: "keyboard artist", title: "Keyboard Tour", slug: "keyboard-tour", venue_id: venue_id,
      status: "published", published_at: 1.day.ago, start_at: 1.week.from_now, publish_on_russ_live: true,
      created_at: Time.current, updated_at: Time.current
    } ], returning: %w[id]).rows.first.first
    image_id = EventImage.insert_all!([ { event_id: event_id, purpose: "slider", alt_text: "Keyboard press image", created_at: Time.current, updated_at: Time.current } ], returning: %w[id]).rows.first.first
    File.open(Rails.root.join("app/assets/images/russ_live/references/01-disgusting-food-museum.jpg")) do |file|
      blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: "press.jpg", content_type: "image/jpeg", service_name: "test")
      ActiveStorage::Attachment.insert_all!([ { name: "file", record_type: "EventImage", record_id: image_id, blob_id: blob.id, created_at: Time.current } ])
    end
  end
end
