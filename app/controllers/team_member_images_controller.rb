class TeamMemberImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    image = TeamMemberImage.find(params[:id])

    if image.uploaded? && (path = uploaded_image_path(image))
      expires_in 1.year, public: true
      send_data path.binread,
                type: image.content_type.presence || "application/octet-stream",
                disposition: "inline",
                filename: image.filename.presence || "team-member-image"
    else
      redirect_to helpers.asset_path(image.asset_path.presence || "russ_live/team/michaela-russ.jpg")
    end
  end

  private
    def uploaded_image_path(image)
      directory = Rails.root.join("storage", "team_member_images", image.id.to_s)
      return unless directory.directory?

      path = directory.children.find { |child| child.file? && child.basename.to_s.start_with?("original.") }
      return if path.blank?
      return unless path.realpath.to_s.start_with?("#{directory.realpath}/")

      path
    end
end
