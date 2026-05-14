require "test_helper"

class AuthRecordTest < ActiveSupport::TestCase
  setup do
    StuttgartLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
  end

  test "auth records use the writable Russ database" do
    user = create_stuttgart_user!
    session = Session.create!(user: user)

    assert_equal "russ", AuthRecord.connection_db_config.name
    assert AuthRecord.connection.data_source_exists?(:sessions)
    assert_not ActiveRecord::Base.connection.data_source_exists?(:sessions)
    assert_equal user, session.reload.user
  end
end
