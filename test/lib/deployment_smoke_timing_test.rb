require "test_helper"
require "socket"
require "openssl"
require_relative "../../script/ops/deployment_smoke"

class DeploymentSmokeTimingTest < ActiveSupport::TestCase
  test "cold staging response can finish after twenty seconds" do
    with_delayed_https(seconds: 20) do
      begin
        response = Ops::DeploymentSmoke.request(URI("https://staging.stuttgart-live.de/"), nil)
      rescue Net::ReadTimeout
        flunk "Kalte Staging-Antwort wurde vor ihrer Fertigstellung abgebrochen"
      end
      assert_equal "ready", response.body
    end
  end

  test "production still times out before a twenty second response" do
    with_delayed_https(seconds: 20) do
      assert_raises(Net::ReadTimeout) { Ops::DeploymentSmoke.request(URI("https://stuttgart-live.de/"), nil) }
    end
  end

  test "staging does not wait indefinitely for a stalled response" do
    with_delayed_https(seconds: 90) do
      assert_raises(Net::ReadTimeout) { Ops::DeploymentSmoke.request(URI("https://staging.stuttgart-live.de/"), nil) }
    end
  end

  private

  # Real TLS and Net::HTTP, with both the response delay and read deadline scaled
  # equally so the cold-start regression does not take minutes to exercise.
  def with_delayed_https(seconds:)
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=staging.stuttgart-live.de")
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    extension = OpenSSL::X509::ExtensionFactory.new
    extension.subject_certificate = extension.issuer_certificate = certificate
    certificate.add_extension(extension.create_extension("basicConstraints", "CA:TRUE", true))
    certificate.add_extension(extension.create_extension("subjectAltName", "DNS:staging.stuttgart-live.de,DNS:stuttgart-live.de"))
    certificate.sign(key, OpenSSL::Digest::SHA256.new)
    context = OpenSSL::SSL::SSLContext.new
    context.cert, context.key = certificate, key
    listener = TCPServer.new("127.0.0.1", 0)
    server = OpenSSL::SSL::SSLServer.new(listener, context)
    thread = Thread.new do
      loop do
        connection = server.accept
        begin
          loop do
            line = connection.gets
            break if line.nil? || line == "\r\n"
          end
          sleep seconds / 100.0
          connection.write("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nready")
        rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
          # A client timing out closes its test connection before the response.
        ensure
          connection.close
        end
      end
    rescue IOError, SystemCallError
      # Closing the listener ends the test server.
    end
    constructor = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) do |host, *|
      client = constructor.call(host, listener.addr[1], nil)
      client.ipaddr = "127.0.0.1"
      client.cert_store = OpenSSL::X509::Store.new.add_cert(certificate)
      setter = client.method(:read_timeout=)
      client.define_singleton_method(:read_timeout=) { |value| setter.call(value / 100.0) }
      client
    end
    yield
  ensure
    Net::HTTP.define_singleton_method(:new, constructor) if constructor
    listener&.close
    thread&.join(2)
    thread&.kill
  end
end
