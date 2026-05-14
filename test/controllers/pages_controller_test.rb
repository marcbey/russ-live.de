require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
  end

  test "renders public pages" do
    {
      root_path => "Ihr örtlicher",
      unternehmen_path => "Veranstaltungen",
      services_path => "Live",
      referenzen_path => "Projekte, Projekte, Projekte",
      jobs_path => "Unsere aktuellen Jobangebote",
      job_path("stagehands") => "Jobdetails Stagehands",
      presse_path => "Presseinfos für Partner und Medien.",
      kontakt_path => "Charlottenplatz 17",
      impressum_path => "Impressum",
      datenschutz_path => "Datenschutz",
      agb_path => "AGB",
      jugendschutz_path => "Jugendschutz"
    }.each do |path, text|
      get path

      assert_response :success
      assert_includes response.body, text
      assert_includes response.body, "/assets/russ_live/"
    end
  end

  test "renders job detail on its own page" do
    get job_path("stagehands")

    assert_response :success
    assert_includes response.body, "Stagehands"
    assert_includes response.body, "Jobdetails Stagehands"
    assert_includes response.body, "Auf- und Abbau von Bühnen-, Licht- und Tontechnik"
  end

  test "jobs overview links to separate job pages" do
    get jobs_path

    assert_response :success
    assert_includes response.body, job_path("cateringhilfen")
    assert_includes response.body, job_path("stagehands")
    assert_no_match(/Jobdetails Stagehands/, response.body)
  end
end
