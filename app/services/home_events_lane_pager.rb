require "set"

class HomeEventsLanePager
  Result = Data.define(:events, :next_cursor)

  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 20
  CURSOR_SALT = "pages/home_events_lane_cursor".freeze

  class InvalidCursor < StandardError; end

  def self.decode_cursor(cursor)
    return if cursor.blank?

    verifier.verify(cursor)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.verifier
    Rails.application.message_verifier(CURSOR_SALT)
  end

  def initialize(relation:, cursor: nil, per_page: DEFAULT_PER_PAGE)
    @relation = relation
    @cursor_payload = self.class.decode_cursor(cursor)
    @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)

    raise InvalidCursor if cursor.present? && @cursor_payload.blank?
  end

  def call
    events, last_scanned_event, seen_series_ids = paged_events

    Result.new(
      events: events,
      next_cursor: next_cursor_for(last_scanned_event, seen_series_ids, events.size)
    )
  end

  private

  attr_reader :cursor_payload, :per_page, :relation

  def paged_events
    selected_events = []
    seen_series_ids = Set.new(cursor_state.fetch("seen_series_ids", []).map(&:to_i))
    current_relation = apply_cursor(relation)
    last_scanned_event = nil

    loop do
      batch = current_relation.limit(per_page * 4).to_a
      break if batch.empty?

      batch.each do |event|
        last_scanned_event = event
        series_id = event.event_series_id
        next if series_id.present? && seen_series_ids.include?(series_id.to_i)

        selected_events << event
        seen_series_ids << series_id.to_i if series_id.present?
        break if selected_events.size >= per_page
      end

      break if selected_events.size >= per_page
      break if batch.size < per_page * 4

      current_relation = relation_after(last_scanned_event)
    end

    [ selected_events, last_scanned_event, seen_series_ids ]
  end

  def apply_cursor(scope)
    state = cursor_state
    return scope if state.blank?

    relation_after_position(Time.zone.parse(state.fetch("last_start_at")), state.fetch("last_id"))
  end

  def relation_after(event)
    return relation.none if event.blank?

    relation_after_position(event.start_at, event.id)
  end

  def relation_after_position(start_at, id)
    relation.where("start_at > :start_at OR (start_at = :start_at AND id > :id)", start_at:, id:)
  end

  def next_cursor_for(event, seen_series_ids, selected_count)
    return if event.blank?

    state = {
      "last_start_at" => event.start_at.iso8601(6),
      "last_id" => event.id,
      "seen_series_ids" => seen_series_ids.to_a,
      "position" => cursor_state.fetch("position", 0).to_i + selected_count
    }
    return unless relation_after_position(event.start_at, event.id).exists?

    self.class.verifier.generate(state)
  end

  def cursor_state
    cursor_payload || {}
  end
end
