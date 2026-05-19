class ReferenceImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    reference_image = ReferenceImage.find(params[:id])

    if current_variant_uploaded?(reference_image) && (path = uploaded_image_path(reference_image))
      expires_in 1.year, public: true
      send_data path.binread,
                type: current_variant_content_type(reference_image).presence || "application/octet-stream",
                disposition: "inline",
                filename: current_variant_filename(reference_image).presence || "reference-image"
    else
      redirect_to helpers.asset_path(current_variant_asset_path(reference_image).presence || "russ_live/keyvisuals/references-tropfen.png")
    end
  end

  private
    def uploaded_image_path(reference_image)
      directory = Rails.root.join("storage", "reference_images", reference_image.id.to_s)
      return unless directory.directory?

      basename = slider_variant? ? "slider." : "original."
      path = directory.children.find { |child| child.file? && child.basename.to_s.start_with?(basename) }
      return if path.blank?

      real_directory = directory.realpath.to_s
      real_path = path.realpath.to_s
      return unless real_path.start_with?("#{real_directory}/")

      path
    end

    def slider_variant?
      params[:variant] == "slider"
    end

    def current_variant_uploaded?(reference_image)
      slider_variant? ? reference_image.slider_uploaded? : reference_image.uploaded?
    end

    def current_variant_asset_path(reference_image)
      slider_variant? ? reference_image.slider_asset_path : reference_image.asset_path
    end

    def current_variant_content_type(reference_image)
      slider_variant? ? reference_image.slider_content_type : reference_image.content_type
    end

    def current_variant_filename(reference_image)
      slider_variant? ? reference_image.slider_filename : reference_image.filename
    end
end
