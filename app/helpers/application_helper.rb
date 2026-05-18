module ApplicationHelper
  def backend_user?
    authenticated? && current_user&.backend_access?
  end

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

  def public_backend_link(label:, path:, aria_label: nil, class_name: "public-button section-button public-admin-link", wrapper_class: nil, data: {})
    return unless backend_user?

    link = link_to(
      label,
      path,
      class: class_name,
      aria: (aria_label.present? ? { label: aria_label } : {}),
      data: data.reverse_merge(role: "public-admin-edit-link")
    )

    return link if wrapper_class.blank?

    content_tag(:div, link, class: wrapper_class)
  end

  def locale_return_to_path
    query_parameters = request.query_parameters.except("locale")
    query_string = query_parameters.to_query

    query_string.present? ? "#{request.path}?#{query_string}" : request.path
  end

  def localized_reference_partner(reference)
    if reference.production.present?
      t("references.card.partner", production: reference.production)
    else
      t("references.card.fallback_partner")
    end
  end

  def reference_image_source(reference_image)
    return if reference_image.blank?
    return reference_image_path(reference_image, v: reference_image.updated_at.to_i) if reference_image.uploaded?

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

  def reference_image_file_metadata(reference_image)
    return [] if reference_image.blank? || !reference_image.image?

    filename = reference_image.filename.presence || File.basename(reference_image.asset_path.to_s)
    content_type = reference_image.content_type.presence || Rack::Mime.mime_type(File.extname(filename), nil)
    byte_size = reference_image.byte_size.presence || reference_image_asset_byte_size(reference_image)

    [
      [ t("file_metadata.name"), filename ],
      [ t("file_metadata.type"), content_type ],
      [ t("file_metadata.size"), (number_to_human_size(byte_size) if byte_size.present?) ]
    ].select { |_, value| value.present? }
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
    return fallback_reference_home_card_data(reference) unless reference.respond_to?(:reference_image)

    {
      title: reference.title,
      date_location: [ l(reference.starts_on, format: "%d.%m.%Y"), reference.location ].compact_blank.join(" · "),
      partner: localized_reference_partner(reference),
      image: reference_image_source(reference.reference_image),
      alt: reference.reference_image&.display_alt_text || reference.title,
      dimensions: reference_card_dimensions(reference.reference_image),
      image_style: reference_image_style(reference.reference_image),
      image_render_data: reference_image_render_data(reference.reference_image)
    }
  end

  def job_image_source(job_image)
    stored_image_source(job_image, route_helper: :job_image_path)
  end

  def contact_image_source(contact_image)
    stored_image_source(contact_image, route_helper: :contact_image_path)
  end

  def stored_image_file_metadata(stored_image)
    return [] if stored_image.blank? || !stored_image.image?

    filename = stored_image.filename.presence || File.basename(stored_image.asset_path.to_s)
    content_type = stored_image.content_type.presence || Rack::Mime.mime_type(File.extname(filename), nil)
    byte_size = stored_image.byte_size.presence || stored_image_asset_byte_size(stored_image)

    [
      [ t("file_metadata.name"), filename ],
      [ t("file_metadata.type"), content_type ],
      [ t("file_metadata.size"), (number_to_human_size(byte_size) if byte_size.present?) ]
    ].select { |_, value| value.present? }
  end

  private
    def stored_image_source(stored_image, route_helper:)
      return if stored_image.blank?
      return public_send(route_helper, stored_image, v: stored_image.updated_at.to_i) if stored_image.uploaded?

      image_path(stored_image.asset_path) if stored_image.asset_path.present?
    end

    def stored_image_asset_byte_size(stored_image)
      return if stored_image.asset_path.blank?

      asset_root = Rails.root.join("app/assets/images")
      asset_path = asset_root.join(stored_image.asset_path).cleanpath
      return unless asset_path.to_s.start_with?("#{asset_root}/")
      return unless File.file?(asset_path)

      File.size(asset_path)
    end

    def reference_image_asset_byte_size(reference_image)
      return if reference_image.asset_path.blank?

      asset_root = Rails.root.join("app/assets/images")
      asset_path = asset_root.join(reference_image.asset_path).cleanpath
      return unless asset_path.to_s.start_with?("#{asset_root}/")
      return unless File.file?(asset_path)

      File.size(asset_path)
    end

    def fallback_reference_home_card_data(reference)
      {
        title: reference[:title],
        date_location: reference[:date_location],
        partner: reference[:partner],
        image: image_path(reference[:image]),
        alt: reference[:alt],
        dimensions: { width: 920, height: 400 },
        image_render_data: {}
      }
    end
end
