require "test_helper"

class JobImageTest < ActiveSupport::TestCase
  setup do
    RussLiveSchema.ensure!
    JobImage.delete_all
    Job.delete_all
  end

  test "compresses uploaded images through shared upload concern" do
    job = Job.create!(title: "Stagehands", slug: "stagehands", location: "Stuttgart", status: "published")
    image = job.create_job_image!
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("app/assets/images/russ_live/jobs/cateringhilfen.jpg"),
      "image/jpeg"
    )

    image.write_uploaded_file!(upload)
    image.reload

    assert_equal "job_images/#{image.id}/original.webp", image.file_path
    assert_equal "cateringhilfen.webp", image.filename
    assert_equal "image/webp", image.content_type
    assert_operator image.byte_size, :<, upload.size
  end
end
