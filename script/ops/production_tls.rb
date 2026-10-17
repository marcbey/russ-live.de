require "openssl"
require_relative "release_support"

module Ops
  module ProductionTls
    def self.validate!(certificate:, private_key:, hosts:)
      cert = OpenSSL::X509::Certificate.new(certificate)
      key = OpenSSL::PKey.read(private_key)
      names = cert.extensions.select { |extension| extension.oid == "subjectAltName" }.flat_map { |extension| extension.value.split(/,\s*/) }
      valid = key.private? && key.public_to_der == cert.public_key.public_to_der &&
        cert.not_before <= Time.now && cert.not_after > Time.now && hosts.all? { |host| names.include?("DNS:#{host}") }
      raise ReleaseSupport::Error, "Vorab-TLS: Schlüssel, Gültigkeit oder Zielnamen stimmen nicht" unless valid
      true
    rescue OpenSSL::OpenSSLError, ArgumentError
      raise ReleaseSupport::Error, "Vorab-TLS: ungültiges Zertifikat oder Schlüssel"
    end
  end
end
