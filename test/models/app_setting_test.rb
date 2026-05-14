require "test_helper"

class AppSettingTest < ActiveSupport::TestCase
  setup do
    StuttgartLiveSchema.ensure!
    AppSetting.delete_all
  end

  test "normalizes sks promoter ids from app settings" do
    AppSetting.insert_all!([
      {
        key: AppSetting::SKS_PROMOTER_IDS_KEY,
        value: [ "10135", "10136, 382", "10135" ],
        created_at: Time.current,
        updated_at: Time.current
      }
    ])

    assert_equal %w[10135 10136 382], AppSetting.sks_promoter_ids
  end
end
