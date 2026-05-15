module ApplicationHelper
  def public_page?(key)
    @page_key == key.to_sym
  end

  def public_section?(keys)
    keys.map(&:to_sym).include?(@page_key)
  end

  def public_nav_aria(keys)
    { aria: { current: "page" } } if public_section?(Array(keys))
  end

  def public_nav_class(keys, class_name: "is-active")
    class_name if public_section?(Array(keys))
  end

  def reference_image_source(reference_image)
    return if reference_image.blank?
    return reference_image_path(reference_image) if reference_image.uploaded?

    image_path(reference_image.asset_path) if reference_image.asset_path.present?
  end

  def reference_image_style(reference_image)
    return if reference_image.blank?

    focus_x = reference_image.card_focus_x_value
    focus_y = reference_image.card_focus_y_value
    zoom = (reference_image.card_zoom_value / 100.0).round(3)

    [
      "object-position: #{focus_x}% #{focus_y}%",
      "--reference-image-focus-x: #{focus_x}%",
      "--reference-image-focus-y: #{focus_y}%",
      "--reference-image-zoom: #{zoom}"
    ].join("; ")
  end

  def reference_image_render_data(reference_image)
    return {} if reference_image.blank?

    {
      controller: "reference-image-render",
      reference_image_render_focus_x_value: reference_image.card_focus_x_value,
      reference_image_render_focus_y_value: reference_image.card_focus_y_value,
      reference_image_render_zoom_value: reference_image.card_zoom_value
    }
  end

  def reference_grid_class(reference_image)
    case reference_image&.grid_variant
    when ReferenceImage::GRID_VARIANT_2X1 then "reference-card-grid-2-1"
    when ReferenceImage::GRID_VARIANT_1X2 then "reference-card-grid-1-2"
    when ReferenceImage::GRID_VARIANT_2X2 then "reference-card-grid-2-2"
    else "reference-card-grid-1-1"
    end
  end

  def reference_card_dimensions(reference_image)
    case reference_image&.grid_variant
    when ReferenceImage::GRID_VARIANT_2X1 then { width: 1000, height: 570 }
    when ReferenceImage::GRID_VARIANT_1X2 then { width: 500, height: 1183 }
    when ReferenceImage::GRID_VARIANT_2X2 then { width: 1000, height: 1000 }
    else { width: 600, height: 600 }
    end
  end

  def reference_home_card_data(reference)
    {
      title: reference.title,
      date_location: [ l(reference.starts_on, format: "%d.%m.%Y"), reference.location ].compact_blank.join(" · "),
      partner: reference.production.present? ? "Partner: #{reference.production}" : "Referenz",
      image: reference_image_source(reference.reference_image),
      alt: reference.reference_image&.display_alt_text || reference.title,
      image_style: reference_image_style(reference.reference_image),
      image_render_data: reference_image_render_data(reference.reference_image)
    }
  end
end
