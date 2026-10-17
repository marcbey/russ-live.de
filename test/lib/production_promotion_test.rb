require "test_helper"
require "open3"

class ProductionPromotionTest < ActiveSupport::TestCase
  test "a stale promotion releases the host lock without deployment while rollback still validates its peer" do
    script = Rails.root.join("script/ops/production_promotion.rb").to_s
    code = <<~'RUBY'
      require ARGV.shift
      class FakeDeployment
        attr_reader :repository, :project, :peer, :remote, :released, :deployed
        def initialize
          @repository, @project, @peer = 'marcbey/stuttgart-live.de', 'stuttgart_live_de', 'russ_live_de'
          @remote = Object.new
          @remote.define_singleton_method(:running) { |**| { 'image' => 'peer', 'commit' => 'peer', 'digest' => 'peer' } }
        end
        def with_lock
          yield
          @released = true
        end
        def deploy!(**)
          @deployed = true
        end
        def notify_sentry!; end
      end
      approval = Object.new
      approval.define_singleton_method(:validate_environment!) { true }
      approval.define_singleton_method(:validate_current!) do |mode:, **|
        raise Ops::ProductionApproval::Superseded, 'newer staging' unless mode == 'rollback'
      end
      evidence = Object.new
      evidence.define_singleton_method(:validate) { |**| true }
      manifest = { 'commit' => 'a' * 40, 'digest' => 'sha256:' + 'b' * 64 }
      fingerprint = Digest::SHA256.hexdigest(JSON.generate(Ops::ImageFingerprint.canonical({ 'image' => 'peer', 'commit' => 'peer', 'digest' => 'peer' })))
      deployment = FakeDeployment.new
      begin
        Ops::ProductionPromotion.call(deployment: deployment, manifest: manifest, mode: 'promote', production_fingerprint: fingerprint, approval: approval, evidence: evidence)
        abort 'stale source accepted'
      rescue Ops::ProductionApproval::Superseded
        abort 'stale refusal fenced host' unless deployment.released && !deployment.deployed
      end
      rollback = FakeDeployment.new
      Ops::ProductionPromotion.call(deployment: rollback, manifest: manifest, mode: 'rollback', production_fingerprint: fingerprint, approval: approval, evidence: evidence)
      abort 'rollback did not deploy' unless rollback.deployed && rollback.released
      evidence.define_singleton_method(:validate) { |**| raise Ops::ReleaseManifest::Error, 'untested production peer' }
      refused = FakeDeployment.new
      begin
        Ops::ProductionPromotion.call(deployment: refused, manifest: manifest, mode: 'rollback', production_fingerprint: fingerprint, approval: approval, evidence: evidence)
        abort 'rollback skipped peer proof'
      rescue Ops::ReleaseManifest::Error
        abort 'peer refusal fenced host or deployed' unless refused.released && !refused.deployed
      end
      changed = FakeDeployment.new
      begin
        Ops::ProductionPromotion.call(deployment: changed, manifest: manifest, mode: 'rollback', production_fingerprint: 'outdated-base', approval: approval, evidence: evidence)
        abort 'changed production base accepted'
      rescue Ops::ReleaseSupport::Error
        abort 'changed base fenced host or deployed' unless changed.released && !changed.deployed
      end
    RUBY
    output, error, status = Open3.capture3("mise", "exec", "--", "ruby", "-e", code, script)
    assert status.success?, output + error
  end
end
