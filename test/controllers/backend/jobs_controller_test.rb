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
    @admin = create_stuttgart_user!(email_address: "admin@russ-live.de", role: "admin")
    @contact = Contact.create!(name: "Sebastian Kränzlein", phone_number: "+49.711.16 353 42", email: "personal@russ-live.de")
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
    assert_includes response.body, "Titel (Header)"
    assert_includes response.body, "Titel EN"
    assert_includes response.body, "Englisch"
    assert_includes response.body, "Optionales Textfeld"
    assert_includes response.body, "Veröffentlichung"
    assert_includes response.body, "Im Backend sichtbar, aber nicht auf der Website veröffentlicht."
    assert_includes response.body, "data-controller=\"backend-sortable-list\""
    assert_includes response.body, "draggable=\"true\""
    assert_select ".editor-tabs-actions .button-publish", "Veröffentlichen"
    assert_select ".editor-tabs-actions .button-secondary", "Vorschau anzeigen"
    assert_select ".editor-tabs-actions .button-danger", "Job löschen"
    assert_select ".editor-tabs-actions .button-success", "Neuer Job"
    assert_operator response.body.index("Speichern"), :<, response.body.index("Veröffentlichen")
    assert_operator response.body.index("Veröffentlichen"), :<, response.body.index("Vorschau anzeigen")
    assert_operator response.body.index("Job löschen"), :<, response.body.index("Neuer Job")
  end

  test "searches jobs by categories and contact" do
    sign_in_as(@admin)
    create_job!(title: "Cateringhilfen", slug: "cateringhilfen", category_list: "Catering")
    create_job!(title: "Logistik", slug: "logistik", category_list: "Logistik", contact: nil)

    get backend_jobs_path(query: "sebastian")

    assert_response :success
    assert_includes response.body, "Cateringhilfen"
    assert_not_includes response.body, 'backend-reference-list-title">Logistik'
    assert_not_includes response.body, "data-controller=\"backend-sortable-list\""

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
    assert_equal [ "Setup", "Teardown" ], job.responsibilities_en
    assert_equal "Text", job.optional_text
    assert_equal "English text", job.optional_text_en
    assert_equal "Neue Stelle", job.job_image.alt_text
    assert_redirected_to backend_jobs_path(job_id: job.id)
  end

  test "creates draft job by default and keeps it selected in all jobs" do
    sign_in_as(@admin)

    post backend_jobs_path, params: {
      job: {
        contact_id: @contact.id,
        title: "Neue Stelle",
        badge: "Minijob",
        intro: "Intro",
        optional_text: "Optionaler Text",
        responsibilities_text: "Aufbau\nAbbau",
        requirements_text: "Teamfähigkeit"
      },
      job_image: {
        alt_text: "Neue Stelle"
      }
    }

    job = Job.last
    assert_equal "draft", job.status
    assert_equal "neue-stelle", job.slug
    assert_equal "Stuttgart", job.location
    assert_equal "Optionaler Text", job.optional_text
    assert_redirected_to backend_jobs_path(job_id: job.id)

    follow_redirect!

    assert_response :success
    assert_select ".status-chip-active", "Alle"
    assert_select ".backend-reference-list-item.is-active .backend-reference-list-title", "Neue Stelle"
  end

  test "previews draft job through backend" do
    sign_in_as(@admin)
    job = create_job!(title: "Entwurf Stelle", slug: "entwurf-stelle", status: "draft")
    job.update!(badge: "Minijob", intro: "Intro", optional_text: "Optionaler Text")

    get preview_backend_job_path(job)

    assert_response :success
    assert_includes response.body, "Entwurf Stelle"
    assert_includes response.body, "Minijob"
    assert_includes response.body, "Optionaler Text"
    assert_includes response.body, "Dieser Job ist noch ein Entwurf"
  end

  test "keeps job selected after publishing from a filtered list" do
    sign_in_as(@admin)
    job = create_job!(title: "Entwurf Stelle", slug: "entwurf-stelle", status: "draft")

    patch backend_job_path(job), params: {
      status: "draft",
      job: job_payload(title: "Entwurf Stelle", slug: "entwurf-stelle", status: "published").fetch(:job)
    }

    assert_redirected_to backend_jobs_path(job_id: job.id)

    follow_redirect!

    assert_select ".status-chip-active", "Alle"
    assert_select ".backend-reference-list-item.is-active .status-badge", "Veröffentlicht"
  end

  test "publish toolbar button saves changes and publishes job" do
    sign_in_as(@admin)
    job = create_job!(title: "Entwurf Stelle", slug: "entwurf-stelle", status: "draft")

    patch backend_job_path(job), params: {
      publish_job: "1",
      job: job_payload(title: "Veröffentlichte Stelle", slug: "entwurf-stelle", status: "draft").fetch(:job)
    }

    assert_redirected_to backend_jobs_path(job_id: job.id)

    job.reload
    assert_equal "Veröffentlichte Stelle", job.title
    assert_equal "published", job.status
  end

  test "reorders jobs from dragged backend list" do
    sign_in_as(@admin)
    catering = create_job!(title: "Catering", slug: "catering", category_list: "Catering")
    stagehands = create_job!(title: "Stagehands", slug: "stagehands", category_list: "Stage")
    marketing = create_job!(title: "Marketing", slug: "marketing", category_list: "Marketing")

    patch reorder_backend_jobs_path, params: {
      job_ids: [ marketing.id, catering.id, stagehands.id ]
    }

    assert_response :success
    assert_equal [ marketing, catering, stagehands ], Job.ordered.to_a
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
          intro_en: "Intro EN",
          highlight_label: "Label",
          highlight_title: "Titel",
          highlight_text: "Text",
          highlight_text_en: "English text",
          category_list: "Catering, Logistik",
          responsibilities_text: "Aufbau\nAbbau",
          responsibilities_en_text: "Setup\nTeardown",
          requirements_text: "Teamfähigkeit\nPünktlichkeit",
          requirements_en_text: "Teamwork\nReliability",
          join_recruiting_url: "",
          meta_title: "#{title} | Jobs",
          meta_title_en: "#{title} | Jobs EN",
          meta_description: "Beschreibung",
          meta_description_en: "Description",
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
