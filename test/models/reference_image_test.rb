require "test_helper"

class ReferenceImageTest < ActiveSupport::TestCase
  setup do
    RussLiveSchema.ensure!
    ReferenceImage.delete_all
    Reference.delete_all
    @reference = Reference.create!(title: "Konzert", starts_on: Date.new(2026, 5, 1), location: "Stuttgart", status: "published")
  end

  test "validates grid variant focus and zoom" do
    image = @reference.build_reference_image(grid_variant: "3x7", card_focus_x: 120, card_focus_y: -1, card_zoom: 90)

    assert_not image.valid?
    assert_includes image.errors[:grid_variant], "is not included in the list"
    assert_includes image.errors[:card_focus_x], "must be less than or equal to 100"
    assert_includes image.errors[:card_focus_y], "must be greater than or equal to 0"
    assert_includes image.errors[:card_zoom], "must be greater than or equal to 100"
  end

  test "normalizes blank grid and crop values" do
    image = @reference.create_reference_image!(grid_variant: "", card_focus_x: "", card_focus_y: "", card_zoom: "")

    assert_equal "1x1", image.grid_variant
    assert_equal 50.0, image.card_focus_x_value
    assert_equal 50.0, image.card_focus_y_value
    assert_equal 100.0, image.card_zoom_value
  end
end
