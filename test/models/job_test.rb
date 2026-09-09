require "test_helper"

class JobTest < ActiveSupport::TestCase
  setup do
    RussLiveSchema.ensure!
    JobImage.delete_all
    Job.delete_all
    ContactImage.delete_all
    Contact.delete_all
  end

  test "validates required fields status and join url" do
    job = Job.new(status: "hidden", join_recruiting_url: "ftp://example.test/job")

    assert_not job.valid?
    assert_includes job.errors[:title], "can't be blank"
    assert_includes job.errors[:location], "can't be blank"
    assert_includes job.errors[:status], "is not included in the list"
    assert_includes job.errors[:join_recruiting_url], "muss eine gültige http- oder https-URL sein"
  end

  test "published scope and ordering" do
    draft = create_job!(title: "Draft", slug: "draft", status: "draft", position: 1)
    published_late = create_job!(title: "Late", slug: "late", status: "published", position: 3)
    published_first = create_job!(title: "First", slug: "first", status: "published", position: 2)

    assert_equal [ published_first, published_late ], Job.published.ordered.to_a
    assert_not_includes Job.published, draft
  end

  test "normalizes categories and exposes slugs" do
    job = create_job!(
      title: "Tagged",
      slug: "tagged",
      status: "published",
      position: 1,
      category_list: "Catering, Logistik\ncatering, Auf-/Abbau"
    )

    assert_equal [ "Catering", "Logistik", "Auf-/Abbau" ], job.categories
    assert_equal "Catering, Logistik, Auf-/Abbau", job.category_list
    assert_equal %w[catering logistik auf-abbau], job.category_slugs
  end

  test "normalizes multiline responsibilities and requirements" do
    job = create_job!(
      title: "Stagehands",
      slug: "stagehands",
      responsibilities_text: "Aufbau\n\nAbbau",
      requirements_text: "Teamfähigkeit\nPünktlichkeit"
    )

    assert_equal [ "Aufbau", "Abbau" ], job.responsibilities
    assert_equal [ "Teamfähigkeit", "Pünktlichkeit" ], job.requirements
  end

  test "maps optional text to stored highlight text" do
    job = create_job!(title: "Stagehands", slug: "stagehands", optional_text: "Optionaler Text")

    assert_equal "Optionaler Text", job.highlight_text
    assert_equal "Optionaler Text", job.optional_text
  end

  test "maps english optional and list text" do
    job = create_job!(
      title: "Stagehands",
      slug: "stagehands",
      optional_text_en: "English optional text",
      responsibilities_en_text: "Setup\nTeardown",
      requirements_en_text: "Teamwork\nReliability"
    )

    assert_equal "English optional text", job.highlight_text_en
    assert_equal "English optional text", job.optional_text_en
    assert_equal [ "Setup", "Teardown" ], job.responsibilities_en
    assert_equal [ "Teamwork", "Reliability" ], job.requirements_en
  end

  test "localizes public job fields with german fallback" do
    job = create_job!(
      title: "Stagehands",
      slug: "stagehands",
      responsibilities_text: "Aufbau",
      requirements_text: "Teamfähigkeit"
    )
    job.update!(
      title_en: "Stage crew",
      badge_en: "Part-time",
      intro_en: "Help behind the scenes.",
      optional_text_en: "English optional text",
      responsibilities_en_text: "Setup",
      requirements_en_text: "Teamwork"
    )

    I18n.with_locale(:en) do
      assert_equal "Stage crew", job.localized_title
      assert_equal "Part-time", job.localized_badge
      assert_equal "Help behind the scenes.", job.localized_intro
      assert_equal "English optional text", job.localized_optional_text
      assert_equal [ "Setup" ], job.localized_responsibilities
      assert_equal [ "Teamwork" ], job.localized_requirements
    end

    job.update!(title_en: "", responsibilities_en: [])

    I18n.with_locale(:en) do
      assert_equal "Stagehands", job.localized_title
      assert_equal [ "Aufbau" ], job.localized_responsibilities
    end
  end

  test "reorders jobs by ids" do
    first = create_job!(title: "First", slug: "first", position: 1)
    second = create_job!(title: "Second", slug: "second", position: 2)
    third = create_job!(title: "Third", slug: "third", position: 3)

    Job.reorder_by_ids!([ third.id, first.id, second.id ])

    assert_equal [ third, first, second ], Job.ordered.to_a
  end

  test "builds application email subject from title" do
    job = create_job!(title: "Stagehands", slug: "stagehands")

    assert_equal "Bewerbung Stagehands", job.application_email_subject
  end

  test "matching searches categories and contact" do
    contact = Contact.create!(name: "Sebastian Kränzlein", phone_number: "+49", email: "personal@russ-live.de")
    tagged = create_job!(title: "Tagged", slug: "tagged", contact: contact, category_list: "Catering")
    create_job!(title: "Other", slug: "other", category_list: "Logistik")

    assert_equal [ tagged ], Job.matching("sebastian").to_a
    assert_equal [ tagged ], Job.matching("cater").to_a
  end

  private
    def create_job!(title:, slug:, status: "published", position: 1, contact: nil, category_list: nil, responsibilities_text: nil, requirements_text: nil, optional_text: nil, optional_text_en: nil, responsibilities_en_text: nil, requirements_en_text: nil)
      Job.create!(
        title: title,
        slug: slug,
        location: "Stuttgart",
        status: status,
        position: position,
        contact: contact,
        category_list: category_list,
        responsibilities_text: responsibilities_text,
        requirements_text: requirements_text,
        optional_text: optional_text,
        optional_text_en: optional_text_en,
        responsibilities_en_text: responsibilities_en_text,
        requirements_en_text: requirements_en_text
      )
    end
end
