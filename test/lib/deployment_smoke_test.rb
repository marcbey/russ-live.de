require "test_helper"
require_relative "../../script/ops/deployment_smoke"

class DeploymentSmokeTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :headers, :html, :large_media) do
    def [](key) = headers[key]
    def body
      raise "Große Mediendatei darf nicht vollständig geladen werden" if large_media
      html
    end
  end

  class FakeSmoke < Ops::DeploymentSmoke
    class << self
      attr_accessor :responses, :requests
      def request(uri, auth, **options)
        requests << { host: uri.host, path: uri.request_uri, auth:, method: options.fetch(:method, :get), connect_ip: options[:connect_ip] }
        responses.shift || raise("Unerwarteter HTTP-Aufruf")
      end
    end
  end

  def responses(media: "/media/signed/video.mp4?x=1&amp;y=2")
    headers = { "x-robots-tag" => "noindex, nofollow", "cache-control" => "private, no-store" }
    [ Response.new("401", headers, "private", false), Response.new("200", headers, "up", false),
      Response.new("200", headers.merge("x-request-id" => "fixture"), "<video src=\"#{media}\"></video>#{'x' * 250}", false),
      Response.new("200", headers.merge("content-length" => "10000000000"), nil, true) ]
  end

  test "staging checks authentication and large media metadata without downloading video bytes" do
    FakeSmoke.responses = responses
    FakeSmoke.requests = []
    assert FakeSmoke.call(host: "staging.stuttgart-live.de", staging: true, auth: "stage:test")
    assert_equal :head, FakeSmoke.requests.last.fetch(:method)
    assert_equal "/media/signed/video.mp4?x=1&y=2", FakeSmoke.requests.last.fetch(:path)
    assert_nil FakeSmoke.requests.first.fetch(:auth)
  end

  test "staging cannot smoke a production media URL" do
    FakeSmoke.responses = responses(media: "https://stuttgart-live.de/media/signed/image.jpg")
    FakeSmoke.requests = []
    assert_raises(Ops::ReleaseSupport::Error) { FakeSmoke.call(host: "staging.stuttgart-live.de", staging: true, auth: "stage:test") }
    assert FakeSmoke.requests.all? { |request| request[:host] == "staging.stuttgart-live.de" }
  end

  test "pre DNS probe keeps TLS hostname and only connects to the pinned Hetzner address" do
    FakeSmoke.responses = responses.drop(1)
    FakeSmoke.requests = []
    assert FakeSmoke.call(host: "stuttgart-live.de", staging: false, connect_ip: "46.225.224.194")
    assert FakeSmoke.requests.all? { |request| request[:host] == "stuttgart-live.de" && request[:connect_ip] == "46.225.224.194" }
    assert_raises(Ops::ReleaseSupport::Error) { FakeSmoke.call(host: "stuttgart-live.de", staging: false, connect_ip: "203.0.113.1") }
    assert_raises(Ops::ReleaseSupport::Error) { FakeSmoke.call(host: "staging.stuttgart-live.de", staging: true, connect_ip: "46.225.224.194") }
  end
end
