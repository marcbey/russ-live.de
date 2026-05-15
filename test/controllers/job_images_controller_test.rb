require "test_helper"

class JobImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    RussLiveSchema.ensure!
    JobImage.delete_all
    Job.delete_all
  end

  test "redirects asset backed job image to asset path" do
    job = Job.create!(title: "Stagehands", slug: "stagehands", location: "Stuttgart", status: "published")
    image = job.create_job_image!(asset_path: "russ_live/jobs/cateringhilfen.jpg")

    get job_image_path(image)

    assert_response :redirect
    assert_includes response.location, "cateringhilfen"
  end
end
