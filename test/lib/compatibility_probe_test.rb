require "test_helper"
require_relative "../../script/ops/compatibility_probe"

class CompatibilityProbeTest < ActiveSupport::TestCase
  test "all probe images share one disconnected transfer and retain their identities" do
    with_docker_boundary do |probe, references, transfers|
      images = probe.send(:load_images, references)

      assert_equal %w[postgres russ_live_de stuttgart_live_de], images.keys.sort
      assert_equal 1, transfers.size, "shared image layers must travel in one archive"
      source, target = transfers.first
      assert_equal [ "docker", "save", *images.values ], source
      assert_equal [ "docker", "exec", "--interactive", "probe-daemon", "docker", "load" ], target
    end
  end

  test "a changed image in a successful batch transfer is rejected" do
    with_docker_boundary(corrupt: true) do |probe, references, _|
      assert_raises(Ops::ReleaseSupport::Error) { probe.send(:load_images, references) }
    end
  end

  test "substituting another valid role image is rejected" do
    with_docker_boundary(corrupt: :wrong_role) do |probe, references, _|
      assert_raises(Ops::ReleaseSupport::Error) { probe.send(:load_images, references) }
    end
  end

  test "either failed pipeline command prevents the probe from using the batch" do
    [ [ false, true ], [ true, false ] ].each do |statuses|
      with_docker_boundary(statuses:) do |probe, references, _|
        assert_raises(Ops::ReleaseSupport::Error) { probe.send(:load_images, references) }
      end
    end
  end

  private

  def with_docker_boundary(corrupt: false, statuses: [ true, true ])
    original_capture = Ops::ReleaseSupport.method(:capture)
    original_pipeline = Open3.method(:pipeline)
    transfers = []
    aliases = {}
    references = { "stuttgart_live_de" => "sha256:#{'a' * 64}", "russ_live_de" => "sha256:#{'b' * 64}", "postgres" => "sha256:#{'c' * 64}" }
    metadata = references.to_h do |role, reference|
      [ reference, { "Architecture" => "amd64", "Os" => "linux", "Config" => { "Cmd" => [ "bin/server" ], "Env" => [ "ROLE=#{role}" ] },
        "RootFS" => { "Type" => "layers", "Layers" => [ "sha256:#{'d' * 64}", reference ] } } ]
    end
    Ops::ReleaseSupport.define_singleton_method(:capture) do |*command, **|
      case command.take(3)
      when [ "docker", "image", "inspect" ]
        JSON.generate([ metadata.fetch(command.last) ])
      when [ "docker", "tag", command[2] ]
        aliases[command.last] = command[2]
        ""
      when [ "docker", "exec", "--interactive" ]
        raise "Image was not transferred" unless transfers.any? { |source, _| source.include?(command.last) }
        value = metadata.fetch(aliases.fetch(command.last))
        if corrupt && command.last.include?("russ_live_de")
          value = corrupt == :wrong_role ? metadata.fetch(references.fetch("postgres")) : value.merge("Config" => { "Cmd" => [ "changed" ] })
        end
        JSON.generate([ value ])
      else
        raise "Unexpected Docker operation: #{command.inspect}"
      end
    end
    Open3.define_singleton_method(:pipeline) do |source, target, **|
      transfers << [ source, target ]
      statuses.map { |success| Struct.new(:success?).new(success) }
    end
    probe = Ops::CompatibilityProbe.new
    probe.instance_variable_set(:@daemon, "probe-daemon")
    probe.instance_variable_set(:@aliases, [])
    yield probe, references, transfers
  ensure
    Ops::ReleaseSupport.define_singleton_method(:capture, original_capture)
    Open3.define_singleton_method(:pipeline, original_pipeline)
  end
end
