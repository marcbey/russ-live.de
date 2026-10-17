require "test_helper"

class TeamMemberTest < ActiveSupport::TestCase
  setup do
    RussLiveSchema.ensure!
    TeamMemberImage.delete_all
    TeamMember.delete_all
  end

  test "validates name and position" do
    member = TeamMember.new(position: -1)

    assert_not member.valid?
    assert_includes member.errors[:name], "can't be blank"
    assert member.errors[:position].any?
  end

  test "orders members by position" do
    second = TeamMember.create!(name: "Zweite Person", position: 2)
    first = TeamMember.create!(name: "Erste Person", position: 1)

    assert_equal [ first, second ], TeamMember.ordered.to_a
  end

  test "uses the localized role with german fallback" do
    member = TeamMember.new(name: "Michaela Russ", role: "Geschäftsführerin", role_en: "Managing Director")

    assert_equal "Geschäftsführerin", I18n.with_locale(:de) { member.localized_role }
    assert_equal "Managing Director", I18n.with_locale(:en) { member.localized_role }

    member.role_en = nil
    assert_equal "Geschäftsführerin", I18n.with_locale(:en) { member.localized_role }
  end
end
