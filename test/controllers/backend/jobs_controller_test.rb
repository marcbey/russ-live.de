require "test_helper"

class Backend::JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    JobImage.delete_all
    Job.delete_all
    ContactImage.delete_all
    Contact.delete_all
    @admin = create_stuttgart_user!(email_address: "admin@example.com", role: "admin")
    @contact = Contact.create!(name: "Sebastian Kränzlein", phone_number: "+49.711.16 353 42", email: "personal@example.com")
  end

  test "requires authentication" do
    get backend_jobs_path

    assert_redirected_to new_session_url
  end

  test "renders inbox with backend navigation" do
    sign_in_as(@admin)
    create_job!(title: "Stagehands", slug: "stagehands")

    get backend_jobs_path

    assert_response :success
    assert_includes response.body, "Jobs"
    assert_includes response.body, "Referenzen"
    assert_includes response.body, "Ansprechpartner"
    assert_includes response.body, "Logout"
    assert_includes response.body, "Stagehands"
  end

  test "searches jobs by categories and contact" do
    sign_in_as(@admin)
    create_job!(title: "Cateringhilfen", slug: "cateringhilfen", category_list: "Catering")
    create_job!(title: "Logistik", slug: "logistik", category_list: "Logistik", contact: nil)

    get backend_jobs_path(query: "sebastian")

    assert_response :success
    assert_includes response.body, "Cateringhilfen"
    assert_not_includes response.body, 'backend-reference-list-title">Logistik'

    get backend_jobs_path(query: "cater")

    assert_response :success
    assert_includes response.body, "Cateringhilfen"
    assert_not_includes response.body, 'backend-reference-list-title">Logistik'
  end

  test "creates published job with image metadata" do
    sign_in_as(@admin)

    assert_difference -> { Job.count }, 1 do
      assert_difference -> { JobImage.count }, 1 do
        post backend_jobs_path, params: job_payload(title: "Neue Stelle", slug: "neue-stelle", status: "published")
      end
    end

    job = Job.last
    assert_equal "published", job.status
    assert_equal [ "Catering", "Logistik" ], job.categories
    assert_equal [ "Aufbau", "Abbau" ], job.responsibilities
    assert_equal "Neue Stelle", job.job_image.alt_text
    assert_redirected_to backend_jobs_path(job_id: job.id, status: "published")
  end

  test "updates image tab without job params" do
    sign_in_as(@admin)
    job = create_job!(title: "Stagehands", slug: "stagehands")

    patch backend_job_path(job), params: {
      editor_tab: "image",
      job_image: {
        alt_text: "Stagehands Team",
        sub_text: "Copyright"
      }
    }

    assert_redirected_to backend_jobs_path(job_id: job.id, editor_tab: "image")
    job.reload
    assert_equal "Stagehands", job.title
    assert_equal "Stagehands Team", job.job_image.alt_text
    assert_equal "Copyright", job.job_image.sub_text
  end

  private
    def create_job!(title:, slug:, status: "published", category_list: "Catering", contact: @contact)
      Job.create!(
        contact: contact,
        title: title,
        slug: slug,
        location: "Stuttgart",
        status: status,
        position: 1,
        category_list: category_list
      ).tap do |job|
        job.create_job_image!(asset_path: "russ_live/jobs/cateringhilfen.jpg", alt_text: title)
      end
    end

    def job_payload(title:, slug:, status:)
      {
        job: {
          contact_id: @contact.id,
          title: title,
          slug: slug,
          badge: "Minijob",
          employment: "Flexible Einsätze",
          location: "Stuttgart",
          intro: "Intro",
          highlight_label: "Label",
          highlight_title: "Titel",
          highlight_text: "Text",
          category_list: "Catering, Logistik",
          responsibilities_text: "Aufbau\nAbbau",
          requirements_text: "Teamfähigkeit\nPünktlichkeit",
          join_recruiting_url: "",
          meta_title: "#{title} | Jobs",
          meta_description: "Beschreibung",
          status: status,
          position: "1"
        },
        job_image: {
          alt_text: title,
          sub_text: "Copyright"
        }
      }
    end
end
