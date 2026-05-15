require "test_helper"

class ReferenceTest < ActiveSupport::TestCase
  setup do
    RussLiveSchema.ensure!
    ReferenceImage.delete_all
    Reference.delete_all
  end

  test "validates required fields and status" do
    reference = Reference.new(status: "hidden")

    assert_not reference.valid?
    assert_includes reference.errors[:title], "can't be blank"
    assert_includes reference.errors[:starts_on], "can't be blank"
    assert_includes reference.errors[:location], "can't be blank"
    assert_includes reference.errors[:status], "is not included in the list"
  end

  test "published scope and ordering" do
    draft = create_reference!(title: "Draft", status: "draft", position: 1)
    published_late = create_reference!(title: "Late", status: "published", position: 3, starts_on: Date.new(2025, 1, 1))
    published_first = create_reference!(title: "First", status: "published", position: 2, starts_on: Date.new(2024, 1, 1))

    assert_equal [ published_first, published_late ], Reference.published.ordered.to_a
    assert_not_includes Reference.published, draft
  end

  private
    def create_reference!(title:, status:, position:, starts_on: Date.new(2026, 1, 1))
      Reference.create!(
        title: title,
        starts_on: starts_on,
        location: "Stuttgart",
        status: status,
        position: position
      )
    end
end
