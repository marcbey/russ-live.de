class PressArtist
  FALLBACK_HERO_IMAGE = "russ_live/keyvisuals/Keyvisual_RussLive.jpg".freeze
  STUTTGART_LIVE_EVENT_BASE_URL = "https://www.stuttgart-live.de/events/".freeze

  attr_reader :events, :name, :normalized_name, :slug

  def self.from_events(events)
    grouped_events = events.group_by { |event| event.normalized_artist_name.presence || event.artist_name.to_s.downcase }
    artists = grouped_events.filter_map do |normalized_name, artist_events|
      next if normalized_name.blank?

      new(normalized_name:, events: artist_events.sort_by { |event| [ event.start_at || Time.zone.at(0), event.id.to_i ] })
    end

    assign_slugs(artists.sort_by { |artist| artist.name.downcase })
  end

  def self.grouped(artists)
    artists.group_by(&:letter).sort.to_h
  end

  def initialize(normalized_name:, events:)
    @normalized_name = normalized_name
    @events = events
    @name = display_name_from(events)
  end

  def assign_slug(slug)
    @slug = slug
  end

  def letter
    first_character = name.first.to_s.upcase
    first_character.match?(/[A-ZÄÖÜ]/) ? first_character : "1"
  end

  def primary_event
    @primary_event ||= upcoming_events.first || events.reverse.find { |event| event.start_at.present? } || events.first
  end

  def upcoming_events
    @upcoming_events ||= events.select { |event| event.start_at.present? && event.start_at >= Time.current }.sort_by(&:start_at)
  end

  def additional_events
    events - [ primary_event ]
  end

  def press_body
    rich_text = primary_event.press_text&.body
    return rich_text if rich_text.present?

    primary_event.event_info.to_s.strip.presence
  end

  def hero_image
    image = primary_event.event_image
    return image if image.present? && image.file.attached?

    FALLBACK_HERO_IMAGE
  end

  def gallery_images
    events.flat_map { |event| press_images_for(event) }
      .select { |image| image.file.attached? }
      .uniq { |image| image.file.blob_id }
  end

  def ticket_url
    primary_event.public_ticket_offer&.resolved_ticket_url.presence ||
      "#{STUTTGART_LIVE_EVENT_BASE_URL}#{primary_event.slug}"
  end

  def self.assign_slugs(artists)
    artists.group_by { |artist| base_slug(artist.name) }.flat_map do |base_slug, grouped_artists|
      grouped_artists.each_with_index.map do |artist, index|
        artist.assign_slug(index.zero? ? base_slug : "#{base_slug}-#{artist.primary_event.id}")
        artist
      end
    end.sort_by { |artist| artist.name.downcase }
  end
  private_class_method :assign_slugs

  def self.base_slug(name)
    name.to_s.parameterize.presence || "kuenstler"
  end
  private_class_method :base_slug

  private

  def display_name_from(events)
    events.map(&:artist_name)
      .compact_blank
      .min_by { |artist_name| [ artist_name.downcase, artist_name ] }
      .to_s
  end

  def press_images_for(event)
    event_image_blob_id = event.event_image&.file&.blob_id

    event.event_images
      .sort_by { |image| [ image.created_at || Time.zone.at(0), image.id.to_i ] }
      .reject { |image| image.file.blob_id == event_image_blob_id }
  end
end
