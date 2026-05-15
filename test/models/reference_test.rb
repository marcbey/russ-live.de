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

  test "normalizes tag list and exposes slugs" do
    reference = create_reference!(
      title: "Tagged",
      status: "published",
      position: 1,
      tag_list: "Open Air, Clubkonzert\nopen air, Ausstellung, "
    )

    assert_equal [ "Open Air", "Clubkonzert", "Ausstellung" ], reference.tags
    assert_equal "Open Air, Clubkonzert, Ausstellung", reference.tag_list
    assert_equal %w[open-air clubkonzert ausstellung], reference.tag_slugs
  end

  test "matching searches tags" do
    tagged = create_reference!(title: "Tagged", status: "published", position: 1, tag_list: "Open Air")
    create_reference!(title: "Other", status: "published", position: 2, tag_list: "Ausstellung")

    assert_equal [ tagged ], Reference.matching("open").to_a
  end

  test "tags from records are unique and sorted case insensitive" do
    create_reference!(title: "A", status: "published", position: 1, tag_list: "Clubkonzert, Open Air")
    create_reference!(title: "B", status: "published", position: 2, tag_list: "open air, Ausstellung")

    assert_equal [ "Ausstellung", "Clubkonzert", "Open Air" ], Reference.tags_from(Reference.all)
  end

  private
    def create_reference!(title:, status:, position:, starts_on: Date.new(2026, 1, 1), tag_list: nil)
      Reference.create!(
        title: title,
        starts_on: starts_on,
        location: "Stuttgart",
        status: status,
        position: position,
        tag_list: tag_list
      )
    end
end
