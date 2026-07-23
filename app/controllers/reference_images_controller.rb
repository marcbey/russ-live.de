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
      path = reference_image.file_disk_path(variant: current_variant)
      return if path.blank? || !path.file?

      real_directory = Rails.root.join("storage", "reference_images", reference_image.id.to_s).realpath.to_s
      real_path = path.realpath.to_s
      return unless real_path.start_with?("#{real_directory}/")

      path
    end

    def current_variant
      return ReferenceImage::SLIDER_VARIANT if slider_variant?
      return ReferenceImage::SLIDER_MOBILE_VARIANT if slider_mobile_variant?

      ReferenceImage::DEFAULT_VARIANT
    end

    def slider_variant?
      params[:variant] == "slider"
    end

    def slider_mobile_variant?
      params[:variant] == "slider_mobile"
    end

    def current_variant_uploaded?(reference_image)
      case current_variant
      when ReferenceImage::SLIDER_VARIANT
        reference_image.slider_uploaded?
      when ReferenceImage::SLIDER_MOBILE_VARIANT
        reference_image.slider_mobile_uploaded?
      else
        reference_image.uploaded?
      end
    end

    def current_variant_asset_path(reference_image)
      case current_variant
      when ReferenceImage::SLIDER_VARIANT
        reference_image.slider_asset_path
      when ReferenceImage::SLIDER_MOBILE_VARIANT
        reference_image.slider_mobile_asset_path
      else
        reference_image.asset_path
      end
    end

    def current_variant_content_type(reference_image)
      case current_variant
      when ReferenceImage::SLIDER_VARIANT
        reference_image.slider_content_type
      when ReferenceImage::SLIDER_MOBILE_VARIANT
        reference_image.slider_mobile_content_type
      else
        reference_image.content_type
      end
    end

    def current_variant_filename(reference_image)
      case current_variant
      when ReferenceImage::SLIDER_VARIANT
        reference_image.slider_filename
      when ReferenceImage::SLIDER_MOBILE_VARIANT
        reference_image.slider_mobile_filename
      else
        reference_image.filename
      end
    end
end
