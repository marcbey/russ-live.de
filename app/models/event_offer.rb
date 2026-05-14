class EventOffer < SharedStuttgartRecord
  EVENT_ID_TEMPLATE_PLACEHOLDERS = [ "%{event_id}", "{event_id}" ].freeze

  self.table_name = "event_offers"

  belongs_to :event

  scope :ordered, -> { order(priority_rank: :asc, id: :asc) }
  scope :active_ticket, -> { where(sold_out: false).where.not(ticket_url: [ nil, "" ]) }

  def active_ticket?
    !sold_out? && ticket_url.present?
  end

  def resolved_ticket_url
    self.class.resolve_ticket_url(ticket_url, source_event_id)
  end

  def self.resolve_ticket_url(url, source_event_id)
    normalized_url = url.to_s.strip
    return "" if normalized_url.blank?

    normalized_source_event_id = source_event_id.to_s.strip
    return normalized_url if normalized_source_event_id.blank?

    resolved_url = EVENT_ID_TEMPLATE_PLACEHOLDERS.reduce(normalized_url) do |memo, placeholder|
      memo.gsub(placeholder, normalized_source_event_id)
    end

    duplicate_pattern = %r{/#{Regexp.escape(normalized_source_event_id)}/#{Regexp.escape(normalized_source_event_id)}(?=/|\z)}
    resolved_url.sub(duplicate_pattern, "/#{normalized_source_event_id}")
  end
end
