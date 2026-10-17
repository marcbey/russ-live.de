require "test_helper"
require "openssl"
require_relative "../../script/ops/production_tls"

class ProductionTlsTest < ActiveSupport::TestCase
  test "preissued certificate must match key both target names and validity" do
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = OpenSSL::X509::Name.parse("/CN=stuttgart-live.de")
    certificate.issuer = certificate.subject
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    certificate.add_extension(OpenSSL::X509::Extension.new("subjectAltName", "DNS:stuttgart-live.de, DNS:www.stuttgart-live.de"))
    certificate.sign(key, OpenSSL::Digest.new("SHA256"))
    assert Ops::ProductionTls.validate!(certificate: certificate.to_pem, private_key: key.to_pem, hosts: %w[stuttgart-live.de www.stuttgart-live.de])
    [ [ key.to_pem, %w[russ-live.de www.russ-live.de] ], [ OpenSSL::PKey::RSA.new(2048).to_pem, %w[stuttgart-live.de www.stuttgart-live.de] ] ].each do |private_key, hosts|
      assert_raises(Ops::ReleaseSupport::Error) { Ops::ProductionTls.validate!(certificate: certificate.to_pem, private_key:, hosts:) }
    end
    certificate.not_after = Time.now - 1
    certificate.sign(key, OpenSSL::Digest.new("SHA256"))
    assert_raises(Ops::ReleaseSupport::Error) { Ops::ProductionTls.validate!(certificate: certificate.to_pem, private_key: key.to_pem, hosts: %w[stuttgart-live.de www.stuttgart-live.de]) }
  end
end
