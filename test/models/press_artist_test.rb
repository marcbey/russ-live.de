require "test_helper"

class PressArtistTest < ActiveSupport::TestCase
  EventStub = Data.define(:id, :artist_name, :normalized_artist_name, :start_at, :slug)

  test "adds event id suffix when artist slugs collide" do
    left = EventStub.new(10, "AC DC", "ac dc", Time.zone.local(2026, 6, 1), "ac-dc")
    right = EventStub.new(20, "AC/DC", "ac/dc", Time.zone.local(2026, 6, 2), "ac-dc-2")

    artists = PressArtist.from_events([ left, right ])

    assert_equal [ "ac-dc", "ac-dc-20" ], artists.map(&:slug)
  end
end
