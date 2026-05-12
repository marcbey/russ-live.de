require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "renders public pages" do
    {
      root_path => "Ihr örtlicher Veranstalter für Stuttgart",
      unternehmen_path => "Veranstaltungen",
      services_path => "Live",
      referenzen_path => "Projekte, Projekte, Projekte",
      jobs_path => "Catering - hilfen",
      presse_path => "Pressebereich",
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
end
