require "test_helper"
require "open3"
require "timeout"
require_relative "../../script/ops/production_approval"

lock_file = File.expand_path("../../script/ops/deploy_lock.rb", __dir__)
require lock_file if File.file?(lock_file)

class DeployLockTest < ActiveSupport::TestCase
  setup do
    assert defined?(Ops::DeployLock), "Shared-host deploy lock must exist"
    @dir = Dir.mktmpdir("deploy-lock-")
    @key = File.join(@dir, "test-key")
    File.write(@key, "synthetic-key")
    File.write(File.join(@dir, "ssh"), <<~'PYTHON')
      #!/usr/bin/env python3
      import fcntl, os, shlex, sys, time
      if "deploy@test.invalid" not in sys.argv:
          sys.exit(95)
      args = shlex.split(sys.argv[-1])
      if "/var/lock/live-deploy/global.lock" not in args:
          sys.exit(94)
      timeout = float(args[args.index("-w") + 1])
      deadline = time.monotonic() + timeout
      with open(os.environ["LOCK_TEST_FILE"], "w") as lock:
          while True:
              try:
                  fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                  break
              except BlockingIOError:
                  if time.monotonic() >= deadline:
                      sys.exit(73)
                  time.sleep(0.01)
          script = args[-1].replace('/var/lock/live-deploy/active-operation', os.environ['LOCK_TEST_FILE'] + '.fence')
          if os.environ.get("LOCK_TEST_DROP") == "1":
              script = script.replace('cat >/dev/null', 'sleep 0.1; exit 0')
              script = script.replace('IFS= read -r', 'sleep 0.1; exit 0; IFS= read -r')
          os.set_inheritable(lock.fileno(), True)
          os.execvp('sh', ['sh', '-c', script])
    PYTHON
    FileUtils.chmod(0o700, File.join(@dir, "ssh"))
    @env = { "PATH" => "#{@dir}:#{ENV.fetch('PATH')}", "LOCK_TEST_FILE" => File.join(@dir, "host.lock"), "LOCK_TEST_DROP" => nil }
  end

  teardown { FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir) }

  test "independent controller processes cannot overlap their protected blocks" do
    log = File.join(@dir, "events.log")
    code = <<~'CODE'
      require ARGV.shift
      key, log = ARGV
      Ops::DeployLock.with_lock(host: "test.invalid", key_path: key, timeout: 5) do
        File.open(log, "a") { |file| file.puts "enter:#{Process.pid}" }
        sleep 0.2
        File.open(log, "a") { |file| file.puts "exit:#{Process.pid}" }
      end
    CODE
    processes = 2.times.map { Open3.popen3(@env, "mise", "exec", "--", "ruby", "-e", code, lock_path, @key, log) }
    processes.each do |input, output, error, waiter|
      input.close
      assert waiter.value.success?, output.read + error.read
    ensure
      output.close
      error.close
    end
    events = File.readlines(log, chomp: true)
    assert_equal %w[enter exit enter exit], events.map { |line| line.split(":").first }
    assert_equal events[0].split(":").last, events[1].split(":").last
    assert_equal events[2].split(":").last, events[3].split(":").last
  end

  test "timeout never executes a block and failed operations require explicit recovery" do
    with_lock_env do
      Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key) do
        entered = false
        assert_raises(Ops::DeployLock::LockTimeout) do
          Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key, timeout: 0) { entered = true }
        end
        refute entered
      end
      assert_raises(RuntimeError) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key) { raise "synthetic failure" }
      end
      assert_raises(Ops::DeployLock::Error) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key, timeout: 0) { flunk "Unfinished operation was not fenced" }
      end
      recover_fixture
      error = assert_raises(Timeout::Error) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key) { raise Timeout::Error, "managed command timeout" }
      end
      assert_equal "managed command timeout", error.message
      recover_fixture
      assert_equal :released, Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key, timeout: 0) { :released }
    end
  end

  test "lost lock transport fences other controllers while an independent remote mutation continues" do
    with_lock_env do
      ENV["LOCK_TEST_DROP"] = "1"
      remote_marker = File.join(@dir, "remote-mutation-finished")
      mutator_pid = nil
      continued_after_drop = false
      assert_raises(Ops::DeployLock::ConnectionLost) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key) do
          mutator_pid = Process.spawn("sh", "-c", 'sleep 0.7; printf finished > "$1"', "sh", remote_marker, pgroup: true)
          sleep 0.5
          continued_after_drop = true
        end
      end
      refute continued_after_drop
      ENV.delete("LOCK_TEST_DROP")
      refute File.exist?(remote_marker)
      assert_raises(Ops::DeployLock::Error) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key, timeout: 0) { flunk "Another controller entered during remote mutation" }
      end
      Process.wait(mutator_pid)
      assert File.exist?(remote_marker)
      recover_fixture
      assert_equal :released, Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key, timeout: 0) { :released }
    ensure
      Process.wait(mutator_pid) rescue nil if mutator_pid
    end
  end

  test "CLI preserves the managed command exit status" do
    output, status = Open3.capture2e(@env, "mise", "exec", "--", "script/ops/deploy_with_lock",
      "--host", "test.invalid", "--key", @key, "--", "sh", "-c", "exit 37", chdir: Rails.root)
    assert_equal 37, status.exitstatus, output
    assert File.directory?("#{@env.fetch('LOCK_TEST_FILE')}.fence")
  end

  test "lost SSH terminates the managed command process group" do
    marker = File.join(@dir, "must-not-exist")
    output, status = Open3.capture2e(@env.merge("LOCK_TEST_DROP" => "1"), "mise", "exec", "--", "script/ops/deploy_with_lock",
      "--host", "test.invalid", "--key", @key, "--", "sh", "-c", 'sleep 0.5; printf survived > "$1"', "sh", marker, chdir: Rails.root)
    assert_equal 75, status.exitstatus, output
    sleep 0.6
    refute File.exist?(marker), "Managed subprocess survived the lost host lock"
  end

  test "unconfirmed approval cancellation keeps the host fenced against an approved deployment" do
    repository = "marcbey/stuttgart-live.de"
    candidate = { "id" => 10, "event" => "workflow_run", "status" => "waiting", "head_branch" => "main",
      "path" => ".github/workflows/deploy-production.yml", "repository" => { "full_name" => repository }, "head_repository" => { "full_name" => repository } }
    api = Object.new
    api.define_singleton_method(:github_json) do |path|
      path.include?("/workflows/") ? { "workflow_runs" => [ candidate.deep_dup ] } : [ { "environment" => { "name" => "production" } } ]
    end
    api.define_singleton_method(:run) { |*| candidate.deep_dup }
    api.define_singleton_method(:capture) { |*| candidate["status"] = "in_progress" }
    ticks = [ 0, 61 ]
    approval = Ops::ProductionApproval.new(repository:, api:, clock: -> { ticks.shift || 61 }, sleeper: ->(_) { })
    with_lock_env do
      assert_raises(Ops::ReleaseSupport::Error) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key) { approval.supersede_waiting!(current_run_id: 20) }
      end
      assert File.directory?("#{@env.fetch('LOCK_TEST_FILE')}.fence")
      assert_raises(Ops::DeployLock::PendingOperation) do
        Ops::DeployLock.with_lock(host: "test.invalid", key_path: @key, timeout: 0) { flunk "Unconfirmed cancellation allowed deployment" }
      end
      recover_fixture
    end
  end

  private

  def lock_path
    Rails.root.join("script/ops/deploy_lock.rb").to_s
  end

  def recover_fixture
    path = "#{@env.fetch('LOCK_TEST_FILE')}.fence"
    File.unlink(File.join(path, "owner"))
    Dir.rmdir(path)
  end

  def with_lock_env
    previous = @env.keys.index_with { |key| ENV[key] }
    @env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
