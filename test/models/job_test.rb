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

  test "builds application email subject from title" do
    job = create_job!(title: "Stagehands", slug: "stagehands")

    assert_equal "Bewerbung Stagehands", job.application_email_subject
  end

  test "matching searches categories and contact" do
    contact = Contact.create!(name: "Sebastian Kränzlein", phone_number: "+49", email: "personal@example.com")
    tagged = create_job!(title: "Tagged", slug: "tagged", contact: contact, category_list: "Catering")
    create_job!(title: "Other", slug: "other", category_list: "Logistik")

    assert_equal [ tagged ], Job.matching("sebastian").to_a
    assert_equal [ tagged ], Job.matching("cater").to_a
  end

  private
    def create_job!(title:, slug:, status: "published", position: 1, contact: nil, category_list: nil, responsibilities_text: nil, requirements_text: nil)
      Job.create!(
        title: title,
        slug: slug,
        location: "Stuttgart",
        status: status,
        position: position,
        contact: contact,
        category_list: category_list,
        responsibilities_text: responsibilities_text,
        requirements_text: requirements_text
      )
    end
end
