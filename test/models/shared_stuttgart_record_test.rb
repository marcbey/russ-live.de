require "test_helper"

class SharedStuttgartRecordTest < ActiveSupport::TestCase
  test "shared Stuttgart models are read-only" do
    assert Event.allocate.readonly?
    assert EventImage.allocate.readonly?
    assert Venue.allocate.readonly?
  end

  test "shared Stuttgart models keep upstream table and attachment names" do
    assert_equal "events", Event.table_name
    assert_equal "event_images", EventImage.table_name
    assert_equal "venues", Venue.table_name
    assert Event.reflect_on_attachment(:promotion_banner_image)
    assert EventImage.reflect_on_attachment(:file)
  end
end
