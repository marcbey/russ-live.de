require "json"

class AnonymousLogFormatter
  LEVELS = { "WARN" => "warn", "ERROR" => "error", "FATAL" => "fatal" }.freeze
  ERROR_TYPES = %w[
    ActiveRecord::RecordInvalid ActiveRecord::RecordNotFound ArgumentError
    LoadError NameError NoMethodError PG::ConnectionBad RuntimeError TypeError
  ].freeze
  LOGIN_EVENT = /\A\{"event":"login_attempt","outcome":"(?:successful|failed|locked)"\}\z/

  def call(severity, _timestamp, _progname, message)
    if severity == "INFO" && message.is_a?(String) && message.ascii_only? && LOGIN_EVENT.match?(message)
      return "#{message}\n"
    end

    level = LEVELS[severity]
    return "" unless level

    name = message.class.name
    error_class = ERROR_TYPES.include?(name) ? name : "ApplicationError"
    "#{JSON.generate(event: "application_error", level:, error_class:)}\n"
  end
end
