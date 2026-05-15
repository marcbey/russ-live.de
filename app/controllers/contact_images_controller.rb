class ContactImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    contact_image = ContactImage.find(params[:id])

    if contact_image.uploaded? && (path = uploaded_image_path(contact_image))
      expires_in 1.year, public: true
      send_data path.binread,
                type: contact_image.content_type.presence || "application/octet-stream",
                disposition: "inline",
                filename: contact_image.filename.presence || "contact-image"
    else
      redirect_to helpers.asset_path(contact_image.asset_path.presence || "russ_live/team/sebastian-kraenzlein.jpg")
    end
  end

  private
    def uploaded_image_path(contact_image)
      directory = Rails.root.join("storage", "contact_images", contact_image.id.to_s)
      return unless directory.directory?

      path = directory.children.find { |child| child.file? && child.basename.to_s.start_with?("original.") }
      return if path.blank?

      real_directory = directory.realpath.to_s
      real_path = path.realpath.to_s
      return unless real_path.start_with?("#{real_directory}/")

      path
    end
end
