class JobImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    job_image = JobImage.find(params[:id])

    if job_image.uploaded? && (path = uploaded_image_path(job_image))
      expires_in 1.year, public: true
      send_data path.binread,
                type: job_image.content_type.presence || "application/octet-stream",
                disposition: "inline",
                filename: job_image.filename.presence || "job-image"
    else
      redirect_to helpers.asset_path(job_image.asset_path.presence || "russ_live/jobs/cateringhilfen.jpg")
    end
  end

  private
    def uploaded_image_path(job_image)
      directory = Rails.root.join("storage", "job_images", job_image.id.to_s)
      return unless directory.directory?

      path = directory.children.find { |child| child.file? && child.basename.to_s.start_with?("original.") }
      return if path.blank?

      real_directory = directory.realpath.to_s
      real_path = path.realpath.to_s
      return unless real_path.start_with?("#{real_directory}/")

      path
    end
end
