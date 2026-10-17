# Mandatory post-build check: APP_IMAGE=... mise exec -- ruby test/ops/nginx_runtime_check.rb
require "minitest/autorun"
require "base64"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "tmpdir"
require "timeout"

class NginxRuntimeCheck < Minitest::Test
  IMAGE = ENV.fetch("APP_IMAGE")
  SECRET = "runtime-secret-1234567890"
  HTPASSWD = "tester:$6$runtime$ASgV/R6hSX6s0tdGMPY6lm1PZxWWgZM.qY6NKsxIRUmDjc6urwYTl.ptNuMCS5oUwvVLmAqoS2E7FtzGxh8Et."
  ENCODED_PATH = "/a%2Fb?q=%E2%82%AC&x=1+2"

  def setup
    @fixture = Dir.mktmpdir("nginx-runtime-")
    FileUtils.chmod(0o755, @fixture)
    FileUtils.mkdir_p(File.join(@fixture, "public/assets"))
    FileUtils.mkdir_p(File.join(@fixture, "storage/variants/check"))
    File.write(File.join(@fixture, "public/assets/runtime.css"), "body { color: red; }")
    File.write(File.join(@fixture, "public/sitemap.xml"), "<urlset/>")
    File.write(File.join(@fixture, "storage/variants/check/key"), "image-content")
    File.write(File.join(@fixture, "upstream.rb"), <<~'SERVER')
      require "socket"
      server = TCPServer.new("127.0.0.1", 3000)
      loop do
        client = server.accept
        line = client.gets
        next client.close unless line
        method, target = line.split(" ")
        while (header = client.gets) && header != "\r\n"; end
        code = target.start_with?("/not-found") ? 404 : 200
        body = "#{method} #{target}"
        if target.split("?").first == "/up"
          code = Integer(ENV.fetch("TEST_UPSTREAM_HEALTH_CODE", "200"))
          body = code == 200 ? "ok\n" : "unavailable\n"
        end
        client.write("HTTP/1.1 #{code} Test\r\nContent-Type: text/plain\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        client.close
      end
    SERVER
  end

  def teardown
    Open3.capture2e("docker", "rm", "--force", @container) if @container
    FileUtils.remove_entry(@fixture)
  end

  def test_image_is_labeled_for_the_kamal_service
    expected = File.read(File.expand_path("../../config/deploy.yml", __dir__))[/^service:\s+(\w+)$/, 1]
    refute_nil expected
    assert_equal expected, docker!("image", "inspect", "--format", '{{ index .Config.Labels "service" }}', IMAGE).strip
  end

  def test_canonical_redirects_precede_assets_and_media_and_preserve_encoding
    start_nginx({ "CANONICAL_REDIRECT_ENABLED" => "true" })
    [ "www.app.example.invalid", "legacy.example.invalid" ].each do |host|
      [ ENCODED_PATH, "/assets/runtime.css?build=1", "/media/invalid/file.png?q=a%2Fb" ].each do |path|
        response = request(path, host:, method: "POST")
        assert_equal "308", response.code
        assert_equal "https://app.example.invalid#{path}", response["Location"]
      end
    end
    assert_equal "200", request("/").code
  end

  def test_redirects_remain_disabled_until_cutover
    start_nginx({ "CANONICAL_REDIRECT_ENABLED" => "false" })
    assert_equal "200", request("/", host: "legacy.example.invalid").code
  end

  def test_foreign_host_is_rejected_without_a_redirect
    start_nginx({ "CANONICAL_REDIRECT_ENABLED" => "true" })
    response = request(ENCODED_PATH, host: "foreign.example.invalid")
    assert_equal "421", response.code
    assert_nil response["Location"]
  end

  def test_staging_requires_authentication_before_every_content_and_error_response
    start_staging
    [ "/", "/assets/runtime.css", "/sitemap.xml", stable_media, "/media/invalid/file.png", "/not-found", "/up/", "/%75p" ].each do |path|
      response = request(path)
      assert_equal "401", response.code, path
      assert_equal "noindex, nofollow", response["X-Robots-Tag"], path
      assert_includes response["Cache-Control"], "no-store", path
    end
    assert_equal "401", request("/", password: "wrong").code
  end

  def test_authenticated_staging_serves_static_dynamic_and_signed_media_with_noindex
    start_staging
    [ "/", "/assets/runtime.css", "/sitemap.xml", stable_media, expiring_media ].each do |path|
      response = request(path, password: "stage-password")
      assert_equal "200", response.code, path
      assert_equal "noindex, nofollow", response["X-Robots-Tag"], path
      assert_includes response["Cache-Control"], "no-store", path
      assert_equal "image-content", response.body if path.start_with?("/media/")
    end
    response = request("/not-found", password: "stage-password")
    assert_equal "404", response.code
    assert_equal "noindex, nofollow", response["X-Robots-Tag"]
    response = request(stable_media(secret: "wrong-secret"), password: "stage-password")
    assert_equal "403", response.code
    assert_equal "noindex, nofollow", response["X-Robots-Tag"]
  end

  def test_exact_healthcheck_is_public_and_does_not_expose_application_data
    start_staging
    response = request("/up", host: "46.225.224.194")
    assert_equal "200", response.code
    assert_equal "ok\n", response.body
    assert_equal "noindex, nofollow", response["X-Robots-Tag"]
  end

  def test_staging_refuses_to_start_without_an_authentication_hash
    start_staging({ "STAGING_BASIC_AUTH_HTPASSWD" => "" }, expect_failure: true)
    assert_equal "exited", docker!("inspect", "--format", "{{.State.Status}}", @container).strip
  end

  def test_healthcheck_does_not_claim_success_when_puma_is_unhealthy
    start_nginx({ "TEST_UPSTREAM_HEALTH_CODE" => "503" })
    assert_equal "503", request("/up").code
  end

  private

  def start_staging(overrides = {}, expect_failure: false)
    start_nginx({ "APP_ENVIRONMENT" => "staging", "STAGING_NOINDEX" => "false", "STAGING_BASIC_AUTH_HTPASSWD" => HTPASSWD }.merge(overrides), expect_failure:)
  end

  def start_nginx(overrides = {}, expect_failure: false)
    @container = "codex-nginx-check-#{SecureRandom.hex(5)}"
    env = { "APP_ENVIRONMENT" => "production", "APP_HOST" => "app.example.invalid", "APP_ALLOWED_HOSTS" => "app.example.invalid,www.app.example.invalid,legacy.example.invalid",
      "CANONICAL_REDIRECT_ENABLED" => "false", "MEDIA_PROXY_SECRET" => SECRET, "STAGING_NOINDEX" => "false" }.merge(overrides)
    boot = <<~'SHELL'
      set -euo pipefail
      mkdir -p /tmp/nginx/{client_body,proxy,fastcgi,uwsgi,scgi,denied-media}
      if [ -x /rails/bin/render-nginx-config ]; then
        /rails/bin/render-nginx-config
      else
        # Compatibility harness for the existing image's renderer, before extraction.
        export STAGING_NOINDEX_HEADER=''
        if [ "${STAGING_NOINDEX:-}" = true ]; then
          export STAGING_NOINDEX_HEADER='add_header X-Robots-Tag "noindex, nofollow" always;'
        fi
        envsubst '${MEDIA_PROXY_SECRET} ${STAGING_NOINDEX_HEADER}' < /rails/config/nginx.conf.template > /tmp/nginx.conf
      fi
      ruby /runtime-fixture/upstream.rb &
      exec nginx -c /tmp/nginx.conf -g 'daemon off;'
    SHELL
    env_args = env.flat_map { |key, value| [ "--env", "#{key}=#{value}" ] }
    docker!("run", "--detach", "--name", @container, "--publish", "127.0.0.1::80", "--entrypoint", "/bin/bash",
      "--volume", "#{@fixture}:/runtime-fixture:ro", "--volume", "#{@fixture}/public:/rails/public:ro",
      "--volume", "#{@fixture}/storage:/rails/storage:ro", *env_args, IMAGE, "-c", boot)
    @port = nil
    Timeout.timeout(20) do
      loop do
        state = docker!("inspect", "--format", "{{.State.Status}}", @container).strip
        if state == "exited"
          return if expect_failure
          flunk docker!("logs", @container)
        end
        unless expect_failure
          ports = JSON.parse(docker!("inspect", "--format", "{{json .NetworkSettings.Ports}}", @container))
          @port = Integer(ports.fetch("80/tcp").first.fetch("HostPort"))
          begin
            ready = request("/runtime-ready", password: (env["APP_ENVIRONMENT"] == "staging" ? "stage-password" : nil))
            return if ready.code == "200" && ready.body == "GET /runtime-ready"
          rescue Errno::ECONNREFUSED, EOFError, Errno::ECONNRESET
            # Wait only for this isolated test server to accept requests.
          end
        end
        sleep 0.1
      end
    end
  rescue Timeout::Error
    flunk "nginx startup did not reach expected state: #{docker!('logs', @container)}"
  end

  def request(path, host: "app.example.invalid", method: "GET", password: nil)
    message = method == "POST" ? Net::HTTP::Post.new(path) : Net::HTTP::Get.new(path)
    message["Host"] = host
    message.basic_auth("tester", password) if password
    Net::HTTP.start("127.0.0.1", @port, open_timeout: 3, read_timeout: 3) { |http| http.request(message) }
  end

  def stable_media(secret: SECRET)
    path = "variants/check/key"
    signature = Base64.urlsafe_encode64(Digest::MD5.digest("#{path}#{secret}"), padding: false)
    "/media/#{signature}/#{path}/sample.png"
  end

  def expiring_media
    expires = Time.now.to_i + 3600
    path = "variants/check/key"
    signature = Base64.urlsafe_encode64(Digest::MD5.digest("#{expires}/#{path}#{SECRET}"), padding: false)
    "/media/#{expires}/#{signature}/#{path}--sample.png"
  end

  def docker!(*args)
    output, status = Open3.capture2e("docker", *args)
    raise "Docker command failed: #{output}" unless status.success?
    output
  end
end
