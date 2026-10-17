require "test_helper"
require_relative "../../support/staging_database_fixture"

class StagingDataSanitizerTest < ActiveSupport::TestCase
  include StagingDatabaseFixture
  self.use_transactional_tests = false

  setup do
    open_staging_fixture(database: "russ_live_de_staging", schema: Rails.root.join("db/russ_schema.rb"))
  end

  teardown { close_staging_fixture }

  test "contact and team identities are synthetic while public references and image associations survive twice" do
    contact = insert_stage("contacts", name: "Real Person", email: "real@customer.de", phone_number: "071112345", role: "Private")
    image = insert_stage("contact_images", contact_id: contact, file_path: "russ/contacts/image.jpg", alt_text: "Real Person", sub_text: "Real Person")
    team = insert_stage("team_members", name: "Real Team", role: "Real Role", role_en: "Real Role")
    team_image = insert_stage("team_member_images", team_member_id: team, file_path: "russ/team/image.jpg", alt_text: "Real Team")
    reference = insert_stage("references", title: "Public Concert", location: "Stuttgart", starts_on: Date.current, status: "published")
    insert_stage("sessions", user_id: 123, ip_address: "10.0.0.1")
    insert_stage("login_attempts", user_id: 123, outcome: "failed", email_address: "real@customer.de")
    2.times do
      result = Staging::DataSanitizer.call(connection: @stage)
      assert result.values.all? { |count| count.is_a?(Integer) }
      clean = stage_row("contacts", contact)
      assert_equal "contact-#{contact}@example.invalid", clean["email"]
      assert_equal "+49 000 000000", clean["phone_number"]
      assert_not_equal "Real Person", clean["name"]
      assert_not_equal "Real Team", stage_row("team_members", team)["name"]
      assert_equal contact, stage_row("contact_images", image)["contact_id"]
      assert_equal "russ/contacts/image.jpg", stage_row("contact_images", image)["file_path"]
      assert_equal team, stage_row("team_member_images", team_image)["team_member_id"]
      assert_equal "Public Concert", stage_row("references", reference)["title"]
      assert_equal 0, stage_count("sessions")
      assert_equal 0, stage_count("login_attempts")
    end
  end

  test "actual production database is refused before mutation" do
    @stage.execute("CREATE DATABASE russ_live_de_production")
    config = StagingFixtureRecord.connection_db_config.configuration_hash.merge(database: "russ_live_de_production")
    StagingFixtureRecord.establish_connection(config)
    wrong = StagingFixtureRecord.connection
    wrong.execute("CREATE TABLE sentinel (value text)")
    wrong.execute("INSERT INTO sentinel VALUES ('unchanged')")
    assert_raises(Staging::DataSanitizer::Error) { Staging::DataSanitizer.call(connection: wrong) }
    assert_equal "unchanged", wrong.select_value("SELECT value FROM sentinel")
  end

  test "media verifier checks slider and mobile files and rejects traversal" do
    reference = insert_stage("references", title: "Concert", location: "Stuttgart", starts_on: Date.current)
    image = insert_stage("reference_images", reference_id: reference, file_path: "russ/card.jpg", slider_file_path: "russ/slider.jpg", slider_mobile_file_path: "russ/mobile.jpg")
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "russ"))
      %w[card slider].each { |name| File.write(File.join(root, "russ", "#{name}.jpg"), "fixture") }
      assert_raises(Staging::MediaVerifier::Error) { Staging::MediaVerifier.call(connection: @stage, root:) }
      File.write(File.join(root, "russ", "mobile.jpg"), "fixture")
      assert Staging::MediaVerifier.call(connection: @stage, root:)
      @stage.update("UPDATE reference_images SET slider_mobile_file_path = '../private' WHERE id = #{image}")
      assert_raises(Staging::MediaVerifier::Error) { Staging::MediaVerifier.call(connection: @stage, root:) }
    end
  end
end
