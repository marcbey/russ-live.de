require "test_helper"
require_relative "../../script/ops/release_support"

class ImageFingerprintTest < ActiveSupport::TestCase
  test "runtime identity survives Docker storage formats but detects changed layers or command environment" do
    original = { "Id" => "sha256:#{'a' * 64}", "Architecture" => "amd64", "Os" => "linux", "Config" => { "Env" => [ "APP=staging" ], "Cmd" => [ "bin/server" ], "User" => "1000" }, "RootFS" => { "Type" => "layers", "Layers" => [ "sha256:#{'b' * 64}" ] } }
    transferred = Marshal.load(Marshal.dump(original))
    transferred["Id"] = "sha256:#{'c' * 64}"
    assert_equal Ops::ImageFingerprint.call(original), Ops::ImageFingerprint.call(transferred)
    transferred["RootFS"]["Layers"] = [ "sha256:#{'d' * 64}" ]
    assert_not_equal Ops::ImageFingerprint.call(original), Ops::ImageFingerprint.call(transferred)
    transferred = Marshal.load(Marshal.dump(original))
    transferred["Config"]["Env"] = [ "APP=production" ]
    assert_not_equal Ops::ImageFingerprint.call(original), Ops::ImageFingerprint.call(transferred)
  end
end
