require "test_helper"

class Backend::TeamMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    StuttgartLiveSchema.ensure!
    RussLiveSchema.ensure!
    clear_auth_records
    clear_stuttgart_users
    TeamMemberImage.delete_all
    TeamMember.delete_all
    @admin = create_stuttgart_user!(email_address: "admin@russ-live.de", role: "admin")
  end

  test "requires authentication" do
    get backend_team_members_path

    assert_redirected_to new_session_url
  end

  test "renders searchable sortable inbox" do
    sign_in_as(@admin)
    create_team_member!(name: "Michaela Russ", role: "Geschäftsführerin")

    get backend_team_members_path

    assert_response :success
    assert_includes response.body, "Team"
    assert_includes response.body, "Michaela Russ"
    assert_includes response.body, 'data-controller="backend-sortable-list"'
    assert_includes response.body, 'draggable="true"'
    assert_select ".editor-tabs-actions .button-danger", "Teammitglied löschen"
    assert_select ".editor-tabs-actions .button-success", "Neues Teammitglied"
  end

  test "searches by german and english role" do
    sign_in_as(@admin)
    create_team_member!(name: "Michaela Russ", role: "Geschäftsführerin", role_en: "Managing Director")
    create_team_member!(name: "Andere Person", role: "Marketing")

    get backend_team_members_path(query: "managing")

    assert_response :success
    assert_includes response.body, "Michaela Russ"
    assert_not_includes response.body, "Andere Person"
    assert_not_includes response.body, 'data-controller="backend-sortable-list"'
  end

  test "creates team member with image metadata" do
    sign_in_as(@admin)

    assert_difference -> { TeamMember.count }, 1 do
      assert_difference -> { TeamMemberImage.count }, 1 do
        post backend_team_members_path, params: {
          team_member: { name: "Neue Person", role: "Produktion", role_en: "Production" },
          team_member_image: {}
        }
      end
    end

    member = TeamMember.last
    assert_equal "Neue Person", member.name
    assert_equal "Neue Person", member.team_member_image.alt_text
    assert_nil member.team_member_image.sub_text
    assert_redirected_to backend_team_members_path(team_member_id: member.id)
  end

  test "reorders team members from dragged backend list" do
    sign_in_as(@admin)
    first = create_team_member!(name: "Erste Person", position: 1)
    second = create_team_member!(name: "Zweite Person", position: 2)
    third = create_team_member!(name: "Dritte Person", position: 3)

    patch reorder_backend_team_members_path, params: {
      team_member_ids: [ third.id, first.id, second.id ]
    }

    assert_response :success
    assert_equal [ third, first, second ], TeamMember.ordered.to_a
  end

  private
    def create_team_member!(name:, role: "Team", role_en: nil, position: 1)
      TeamMember.create!(name: name, role: role, role_en: role_en, position: position).tap do |member|
        member.create_team_member_image!(asset_path: "russ_live/team/michaela-russ.jpg", alt_text: name)
      end
    end
end
