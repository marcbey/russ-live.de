require "test_helper"

class AnonymousLogFormatterTest < ActiveSupport::TestCase
  test "drops framework request text and retains only a technical error summary" do
    formatter = AnonymousLogFormatter.new
    private_text = "GET /users/synthetic@example.invalid from 192.0.2.33"

    assert_empty formatter.call("INFO", Time.current, nil, private_text)
    assert_equal({ "event" => "application_error", "level" => "error", "error_class" => "ArgumentError" },
      JSON.parse(formatter.call("ERROR", Time.current, nil, ArgumentError.new(private_text))))
  end

  test "forwards only a known login outcome" do
    formatter = AnonymousLogFormatter.new
    login_event = { event: "login_attempt", outcome: "failed" }.to_json

    assert_equal login_event, formatter.call("INFO", Time.current, nil, login_event).strip
    assert_empty formatter.call("INFO", Time.current, nil,
      { event: "login_attempt", outcome: "synthetic@example.invalid" }.to_json)
  end
end
