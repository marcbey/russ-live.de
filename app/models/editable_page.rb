class EditablePage < RussRecord
  STATUSES = %w[draft published].freeze
  LOCALES = %w[de en].freeze
  PAGE_KEYS = %w[kontakt impressum datenschutz agb jugendschutz].freeze
  CONTACT_LEGACY_FIELDS = %w[location directions address_html office_contact_html ticket_hotline].freeze

  PAGE_DEFINITIONS = {
    "kontakt" => {
      label: "Kontakt",
      public_path: "/kontakt",
      i18n_key: "contact",
      meta_key: "kontakt",
      fields: [ { name: "body_html", label: "Kontakttext", rows: 14 } ]
    },
    "impressum" => {
      label: "Impressum",
      public_path: "/impressum",
      i18n_key: "impressum",
      meta_key: "impressum",
      fields: [ { name: "body_html", label: "Text", rows: 24 } ]
    },
    "datenschutz" => {
      label: "Datenschutz",
      public_path: "/datenschutz",
      i18n_key: "datenschutz",
      meta_key: "datenschutz",
      fields: [ { name: "body_html", label: "Text", rows: 28 } ]
    },
    "agb" => {
      label: "AGB",
      public_path: "/agb",
      i18n_key: "agb",
      meta_key: "agb",
      fields: [ { name: "body_html", label: "Text", rows: 28 } ]
    },
    "jugendschutz" => {
      label: "Jugendschutz",
      public_path: "/jugendschutz",
      i18n_key: "jugendschutz",
      meta_key: "jugendschutz",
      fields: [ { name: "body_html", label: "Text links", rows: 16 } ]
    }
  }.freeze

  normalizes :key, :locale, :title, :meta_title, :status, :published_title,
             :published_meta_title, with: ->(value) { value.to_s.strip }

  before_validation :set_defaults, :normalize_content_fields

  validates :key, presence: true, inclusion: { in: PAGE_KEYS }
  validates :locale, presence: true, inclusion: { in: LOCALES }
  validates :title, presence: true, length: { maximum: 180 }
  validates :meta_title, :published_title, :published_meta_title, length: { maximum: 180 }, allow_blank: true
  validates :meta_description, :published_meta_description, length: { maximum: 600 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :key, uniqueness: { scope: :locale }

  scope :ordered, -> { order(:key, :locale) }

  class << self
    def editor_pages(renderer: ApplicationController.renderer)
      ensure_defaults!(renderer:)
      all.to_a.sort_by { |page| [ PAGE_KEYS.index(page.key) || PAGE_KEYS.length, LOCALES.index(page.locale) || LOCALES.length ] }
    end

    def public_page(key, locale:, renderer: ApplicationController.renderer)
      page = find_by(key: key.to_s, locale: locale.to_s)
      return page.public_version if page&.published_at.present?

      default_for(key, locale, renderer:)
    end

    def default_for(key, locale, renderer: ApplicationController.renderer)
      new(default_attributes_for(key.to_s, locale.to_s, renderer:))
    end

    def strip_view_annotations(html)
      html.to_s.gsub(/<!--\s*(?:BEGIN|END)\s+app\/views\/.*?-->\s*/m, "")
    end

    def ensure_defaults!(renderer: ApplicationController.renderer)
      PAGE_KEYS.each do |key|
        LOCALES.each do |locale|
          find_or_create_by!(key:, locale:) do |page|
            defaults = default_attributes_for(key, locale, renderer:)
            page.assign_attributes(defaults.merge(published_defaults(defaults)))
          end
        end
      end
    end

    def default_attributes_for(key, locale, renderer: ApplicationController.renderer)
      definition = PAGE_DEFINITIONS.fetch(key)

      I18n.with_locale(locale.to_sym) do
        {
          key: key,
          locale: locale,
          title: I18n.t("pages.#{definition.fetch(:i18n_key)}.title"),
          content: default_content_for(key, renderer:),
          meta_title: I18n.t("pages.#{definition.fetch(:meta_key)}.meta.title", default: ""),
          meta_description: I18n.t("pages.#{definition.fetch(:meta_key)}.meta.description", default: ""),
          status: "published"
        }
      end
    end

    private
      def default_content_for(key, renderer:)
        return default_contact_content if key == "kontakt"
        return default_youth_content(renderer:) if key == "jugendschutz"

        { "body_html" => strip_view_annotations(renderer.render(partial: "pages/legal/#{key}_#{I18n.locale}")) }
      end

      def default_youth_content(renderer:)
        { "body_html" => strip_view_annotations(renderer.render(partial: "pages/legal/jugendschutz_copy_#{I18n.locale}")) }
      end

      def default_contact_content
        {
          "body_html" => [
            tag_paragraph(I18n.t("pages.contact.paragraphs.location")),
            tag_paragraph(I18n.t("pages.contact.paragraphs.directions")),
            "<p>Charlottenplatz 17<br>70173 Stuttgart</p>",
            "<p>Fon: +49 (0) 711 16 353 11<br>Mail: info@russ-live.de</p>",
            "<p>Tickethotline: +49 (0) 711 550 660 77</p>"
          ].join
        }
      end

      def tag_paragraph(text)
        "<p>#{ERB::Util.html_escape(text)}</p>"
      end

      def published_defaults(defaults)
        {
          published_title: defaults.fetch(:title),
          published_content: defaults.fetch(:content),
          published_meta_title: defaults.fetch(:meta_title),
          published_meta_description: defaults.fetch(:meta_description),
          published_at: Time.current
        }
      end
  end

  def definition
    PAGE_DEFINITIONS.fetch(key)
  end

  def label
    definition.fetch(:label)
  end

  def public_path
    definition.fetch(:public_path)
  end

  def field_definitions
    definition.fetch(:fields)
  end

  def content_field_names
    field_definitions.pluck(:name)
  end

  def content_value(field_name)
    normalized_field_name = field_name.to_s
    field_value = content.to_h.fetch(normalized_field_name, "")
    return legacy_contact_body_html if key == "kontakt" && normalized_field_name == "body_html" && field_value.blank?
    return youth_copy_body_html(field_value) if key == "jugendschutz" && normalized_field_name == "body_html"

    self.class.strip_view_annotations(field_value)
  end

  def public_version
    self.class.new(
      id: id,
      key: key,
      locale: locale,
      title: published_title.presence || title,
      content: published_content.presence || content,
      meta_title: published_meta_title.presence || meta_title,
      meta_description: published_meta_description.presence || meta_description,
      status: "published",
      published_at: published_at
    )
  end

  def publish!
    assign_attributes(
      status: "published",
      published_title: title,
      published_content: content,
      published_meta_title: meta_title,
      published_meta_description: meta_description,
      published_at: Time.current
    )
    save!
  end

  def draft!
    self.status = "draft"
  end

  def published?
    status == "published"
  end

  def display_status
    return "Veröffentlicht" if published?
    return "Entwurf" if published_at.blank?

    "Änderungen gespeichert"
  end

  private
    def set_defaults
      self.status = "published" if status.blank?
      self.content = {} if content.blank?
      self.published_content = {} if published_content.blank?
    end

    def normalize_content_fields
      self.content = normalized_content(content)
      self.published_content = normalized_content(published_content)
    end

    def normalized_content(value)
      value.to_h.transform_keys(&:to_s).transform_values { |field_value| field_value.to_s }
    end

    def legacy_contact_body_html
      CONTACT_LEGACY_FIELDS.filter_map do |field_name|
        field_value = content.to_h[field_name].to_s.strip
        next if field_value.blank?

        "<p>#{self.class.strip_view_annotations(field_value)}</p>"
      end.join
    end

    def youth_copy_body_html(value)
      body_html = self.class.strip_view_annotations(value)
      body_html[/<div class="legal-youth-copy">\s*(.*?)\s*<\/div>/m, 1].presence || body_html
    end
end
