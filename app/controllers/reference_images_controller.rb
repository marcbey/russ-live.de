class ReferenceImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    reference_image = ReferenceImage.find(params[:id])

    if reference_image.uploaded? && (path = uploaded_image_path(reference_image))
      expires_in 1.year, public: true
      send_data path.binread,
                type: reference_image.content_type.presence || "application/octet-stream",
                disposition: "inline",
                filename: reference_image.filename.presence || "reference-image"
    else
      redirect_to helpers.asset_path(reference_image.asset_path.presence || "russ_live/keyvisuals/references-tropfen.png")
    end
  end

  private
    def uploaded_image_path(reference_image)
      directory = Rails.root.join("storage", "reference_images", reference_image.id.to_s)
      return unless directory.directory?

      path = directory.children.find { |child| child.file? && child.basename.to_s.start_with?("original.") }
      return if path.blank?

      real_directory = directory.realpath.to_s
      real_path = path.realpath.to_s
      return unless real_path.start_with?("#{real_directory}/")

      path
    end
end
