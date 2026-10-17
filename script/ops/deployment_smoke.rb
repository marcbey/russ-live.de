require "net/http"
require "uri"
require "cgi"
require_relative "release_support"

module Ops
  class DeploymentSmoke
    STAGING_HOSTS = %w[staging.stuttgart-live.de staging.russ-live.de].freeze
    HOSTS = (STAGING_HOSTS + %w[stuttgart-live.de www.stuttgart-live.de russ-live.de www.russ-live.de stuttgart-live.schopp3r.de russ-live.schopp3r.de]).freeze

    def self.call(host:, staging:, auth: nil, connect_ip: nil)
      raise ReleaseSupport::Error, "Unbekanntes Smoke-Ziel" unless HOSTS.include?(host) && (!staging || STAGING_HOSTS.include?(host))
      raise ReleaseSupport::Error, "Unzulässige direkte Smoke-Verbindung" if connect_ip && (connect_ip != "46.225.224.194" || staging)
      base = URI("https://#{host}")
      if staging
        response = request(base, nil, connect_ip:)
        raise ReleaseSupport::Error, "Staging ist nicht vollständig zugriffsgeschützt" unless response.code == "401" && noindex?(response)
      end
      health = request(base + "/up", nil, connect_ip:)
      raise ReleaseSupport::Error, "Readiness-Smoke fehlgeschlagen" unless health.code == "200" && (!staging || noindex?(health))
      page = request(base, auth, connect_ip:)
      valid = page.code == "200" && page["x-request-id"] && page.body.bytesize > 200 && (!staging || noindex?(page))
      raise ReleaseSupport::Error, "Rails-HTTP-Smoke fehlgeschlagen" unless valid
      media = page.body[/(?:src|poster)=["']([^"']*\/media\/[^"']+)["']/, 1]
      if media
        uri = base + CGI.unescapeHTML(media)
        allowed = staging ? STAGING_HOSTS : HOSTS
        raise ReleaseSupport::Error, "Medium verweist außerhalb des Zielprofils" unless uri.scheme == "https" && allowed.include?(uri.host)
        response = request(uri, auth, method: :head, connect_ip:)
        raise ReleaseSupport::Error, "Medien-Smoke fehlgeschlagen" unless response.code == "200" && response["content-length"].to_i.positive? && (!staging || noindex?(response))
      end
      true
    end

    def self.noindex?(response)
      response["x-robots-tag"].to_s.include?("noindex") && response["cache-control"].to_s.include?("no-store")
    end

    def self.request(uri, auth, method: :get, connect_ip: nil)
      http = Net::HTTP.new(uri.host, 443, nil)
      http.ipaddr = connect_ip if connect_ip
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = STAGING_HOSTS.include?(uri.host) ? 60 : 15
      type = method == :head ? Net::HTTP::Head : Net::HTTP::Get
      request = type.new(uri.request_uri.empty? ? "/" : uri.request_uri)
      request.basic_auth(*auth.split(":", 2)) if auth
      http.start { |connection| connection.request(request) }
    end
  end
end
