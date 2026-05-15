class JobImage < RussRecord
  include RussImageUpload

  belongs_to :job

  def storage_directory
    "job_images"
  end

  private
    def image_owner_name
      job.title
    end
end
