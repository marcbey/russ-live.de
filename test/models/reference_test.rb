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

  test "validates english description length" do
    reference = create_reference!(
      title: "Localized",
      status: "published",
      position: 1,
      description_en: "English project description."
    )

    assert_predicate reference, :valid?

    reference.description_en = "x" * 501

    assert_not reference.valid?
    assert_includes reference.errors[:description_en], "is too long (maximum is 500 characters)"
  end

  test "localized description uses english copy with german fallback" do
    reference = create_reference!(
      title: "Localized",
      status: "published",
      position: 1,
      description: "Deutsche Beschreibung",
      description_en: "English description"
    )

    assert_equal "Deutsche Beschreibung", reference.localized_description(:de)
    assert_equal "English description", reference.localized_description(:en)

    reference.description_en = nil

    assert_equal "Deutsche Beschreibung", reference.localized_description(:en)
  end

  test "published scope and ordering" do
    draft = create_reference!(title: "Draft", status: "draft", position: 1)
    published_first = create_reference!(title: "First", status: "published", position: 9, starts_on: Date.new(2024, 1, 1))
    published_late = create_reference!(title: "Late", status: "published", position: 1, starts_on: Date.new(2025, 1, 1))

    assert_equal [ published_late, published_first ], Reference.published.ordered.to_a
    assert_not_includes Reference.published, draft
  end

  test "references with the same date show newest records first" do
    first = create_reference!(title: "First", status: "published", position: 9, starts_on: Date.new(2026, 1, 1))
    second = create_reference!(title: "Second", status: "published", position: 1, starts_on: Date.new(2026, 1, 1))

    assert_equal [ second, first ], Reference.ordered.to_a
  end

  test "display date text prefers freeform display date over sort date" do
    reference = create_reference!(
      title: "Exhibition",
      status: "published",
      position: 1,
      starts_on: Date.new(2025, 6, 1)
    )

    assert_equal "01.06.2025", reference.display_date_text

    reference.update!(display_date: "Juni 2025 - März 2026")

    assert_equal "Juni 2025 - März 2026", reference.display_date_text
  end

  test "exact display date updates starts_on automatically" do
    reference = create_reference!(
      title: "Exhibition",
      status: "published",
      position: 1,
      starts_on: Date.new(2025, 6, 1)
    )

    reference.update!(display_date: "18.05.2026")

    assert_equal Date.new(2026, 5, 18), reference.starts_on
    assert_equal "18.05.2026", reference.display_date_text
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

  test "tagged with any matches exact tags case insensitive" do
    concert = create_reference!(title: "Concert", status: "published", position: 1, tag_list: "concert")
    konzert = create_reference!(title: "Konzert", status: "published", position: 2, tag_list: "Konzert")
    live = create_reference!(title: "Live", status: "published", position: 3, tag_list: "Live")
    create_reference!(title: "Partial", status: "published", position: 4, tag_list: "Livehouse")
    create_reference!(title: "Other", status: "published", position: 5, tag_list: "Open Air")

    assert_equal [ live, konzert, concert ], Reference.tagged_with_any(%w[Concert Konzert Live]).ordered.to_a
  end

  test "tags from records are unique and sorted case insensitive" do
    create_reference!(title: "A", status: "published", position: 1, tag_list: "Clubkonzert, Open Air")
    create_reference!(title: "B", status: "published", position: 2, tag_list: "open air, Ausstellung")

    assert_equal [ "Ausstellung", "Clubkonzert", "Open Air" ], Reference.tags_from(Reference.all)
  end

  private
    def create_reference!(title:, status:, position:, starts_on: Date.new(2026, 1, 1), tag_list: nil, description: nil, description_en: nil)
      Reference.create!(
        title: title,
        starts_on: starts_on,
        location: "Stuttgart",
        status: status,
        position: position,
        tag_list: tag_list,
        description: description,
        description_en: description_en
      )
    end
end
