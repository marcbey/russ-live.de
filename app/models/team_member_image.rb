class TeamMemberImage < RussRecord
  include RussImageUpload

  belongs_to :team_member

  def storage_directory
    "team_member_images"
  end

  private
    def image_owner_name
      team_member.name
    end
end
