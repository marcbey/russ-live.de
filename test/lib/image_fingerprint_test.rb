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

  test "same Linux image accepts empty legacy Docker inspect fields without hiding changed settings" do
    modern = { "Architecture" => "amd64", "Os" => "linux", "Config" => { "User" => "1000:1000", "Env" => [ "APP=staging" ], "Cmd" => [ "bin/server" ], "ArgsEscaped" => true }, "RootFS" => { "Type" => "layers", "Layers" => [ "sha256:#{'b' * 64}" ] } }
    legacy = Marshal.load(Marshal.dump(modern))
    # Observed after saving the same image from Docker29 and loading it in Docker28.0.4.
    legacy["Config"].merge!("Hostname" => "", "Domainname" => "", "AttachStdin" => false, "AttachStdout" => false,
      "AttachStderr" => false, "Tty" => false, "OpenStdin" => false, "StdinOnce" => false, "Image" => "", "Volumes" => nil, "OnBuild" => nil)
    assert_equal Ops::ImageFingerprint.call(modern), Ops::ImageFingerprint.call(legacy)

    { "Hostname" => "other", "AttachStdin" => true, "Volumes" => { "/extra" => {} }, "OnBuild" => [ "RUN changed" ], "UnknownRuntimeField" => true }.each do |field, value|
      changed = Marshal.load(Marshal.dump(legacy))
      changed["Config"][field] = value
      assert_not_equal Ops::ImageFingerprint.call(modern), Ops::ImageFingerprint.call(changed), field
    end
  end
end
