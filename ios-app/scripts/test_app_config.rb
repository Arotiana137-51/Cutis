#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for fastlane/app_config.rb. Run with: ruby scripts/test_app_config.rb

require "minitest/autorun"
require "tmpdir"
require_relative "../fastlane/app_config"

class AppConfigTest < Minitest::Test
  def values(overrides = {})
    AppConfig::Values.new(
      display_name: "Tattoo Preview", bundle_id: "com.acme.tattoo", team_id: "9ZX8YW7VU6", marketing_version: "0.1.0",
      **overrides
    )
  end

  def test_parse_reads_keys_and_ignores_comments
    settings = AppConfig.parse(<<~XCCONFIG)
      // A comment line
      APP_DISPLAY_NAME = Tattoo Preview
      APP_BUNDLE_ID = com.acme.tattoo // trailing comment
      APP_TEAM_ID=9ZX8YW7VU6

      #include "Other.xcconfig"
    XCCONFIG
    assert_equal "Tattoo Preview", settings["APP_DISPLAY_NAME"]
    assert_equal "com.acme.tattoo", settings["APP_BUNDLE_ID"]
    assert_equal "9ZX8YW7VU6", settings["APP_TEAM_ID"]
    assert_equal 3, settings.size
  end

  def test_the_real_config_file_loads
    config = AppConfig.load
    refute_empty config.display_name
    refute_empty config.bundle_id
    refute_empty config.team_id
    assert_match(/\A\d+(\.\d+){0,2}\z/, config.marketing_version)
  end

  def test_load_reports_missing_keys
    Dir.mktmpdir do |dir|
      path = File.join(dir, "App.xcconfig")
      File.write(path, "APP_DISPLAY_NAME = X\n")
      error = assert_raises(AppConfig::Error) { AppConfig.load(path) }
      assert_includes error.message, "APP_BUNDLE_ID"
      assert_includes error.message, "APP_TEAM_ID"
    end
  end

  def test_valid_config_has_no_problems
    assert_empty AppConfig.problems(values)
  end

  def test_placeholders_are_reported
    problems = AppConfig.problems(values(bundle_id: "BUNDLE_ID_PLACEHOLDER", team_id: "TEAM_ID_PLACEHOLDER"))
    assert_equal 2, problems.size
    assert(problems.any? { |problem| problem.include?("APP_BUNDLE_ID") })
    assert(problems.any? { |problem| problem.include?("APP_TEAM_ID") })
  end

  def test_bad_values_are_reported
    assert_equal 1, AppConfig.problems(values(bundle_id: "tattoo")).size
    assert_equal 1, AppConfig.problems(values(bundle_id: "com.acme.tattoo preview")).size
    assert_equal 1, AppConfig.problems(values(bundle_id: "com.example.tattoo")).size
    assert_equal 1, AppConfig.problems(values(team_id: "abc")).size
    assert_equal 1, AppConfig.problems(values(team_id: "9zx8yw7vu6")).size
    assert_equal 1, AppConfig.problems(values(team_id: "A1B2C3D4E5")).size
    assert_equal 1, AppConfig.problems(values(marketing_version: "v1")).size
    assert_equal 1, AppConfig.problems(values(display_name: "")).size
  end

  def test_profile_name_matches_project_yml
    project = File.read(File.expand_path("../project.yml", __dir__))
    assert_includes project, "PROVISIONING_PROFILE_SPECIFIER: #{AppConfig.profile_name('$(APP_BUNDLE_ID)')}"
  end

  # ── API key handling ───────────────────────────────────────────────────────

  def sample_key
    @sample_key ||= OpenSSL::PKey::EC.generate("prime256v1")
  end

  def sample_pem
    # Apple's .p8 files are PKCS#8 ("BEGIN PRIVATE KEY").
    sample_key.private_to_pem
  end

  def test_normalize_accepts_plain_text_windows_line_endings_and_base64
    plain = AppConfig.normalize_p8(sample_pem)
    assert_includes plain, "BEGIN PRIVATE KEY"
    assert_equal plain, AppConfig.normalize_p8(sample_pem.gsub("\n", "\r\n"))
    assert_equal plain, AppConfig.normalize_p8("  #{sample_pem}  \n\n")
    assert_equal plain, AppConfig.normalize_p8(Base64.strict_encode64(sample_pem))
    assert_equal plain, AppConfig.normalize_p8(Base64.encode64(sample_pem))
  end

  def test_normalize_rejects_garbage
    assert_raises(AppConfig::Error) { AppConfig.normalize_p8("") }
    assert_raises(AppConfig::Error) { AppConfig.normalize_p8("not a key") }
    assert_raises(AppConfig::Error) do
      AppConfig.normalize_p8("-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----")
    end
  end

  def test_api_token_is_a_valid_es256_jwt
    token = AppConfig.api_token(key_id: "KEY123", issuer_id: "issuer-1", pem: sample_pem, now: 1_800_000_000)
    header, payload, signature = token.split(".")

    assert_equal({ "alg" => "ES256", "kid" => "KEY123", "typ" => "JWT" }, JSON.parse(Base64.urlsafe_decode64(header)))
    claims = JSON.parse(Base64.urlsafe_decode64(payload))
    assert_equal "issuer-1", claims["iss"]
    assert_equal "appstoreconnect-v1", claims["aud"]
    assert_operator claims["exp"] - claims["iat"], :<=, 20 * 60, "Apple refuses tokens that live longer than 20 minutes"

    # Check the signature the way Apple would: with the public key.
    raw = Base64.urlsafe_decode64(signature)
    assert_equal 64, raw.bytesize
    numbers = [raw[0, 32], raw[32, 32]].map { |part| OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(part, 2)) }
    der = OpenSSL::ASN1::Sequence.new(numbers).to_der
    public_key = OpenSSL::PKey.read(sample_key.public_to_pem)
    assert public_key.verify(OpenSSL::Digest.new("SHA256"), der, "#{header}.#{payload}")
  end

  # ── Live check, with Apple's answers faked ────────────────────────────────

  def fake_http(apps:, ids: { code: 200, body: { data: [] }.to_json })
    calls = []
    responder = lambda do |path, query, token|
      calls << [path, query]
      refute_empty token
      path == "/v1/apps" ? apps : ids
    end
    [responder, calls]
  end

  def run_check(http)
    AppConfig.check_apple(bundle_id: "com.acme.tattoo", key_id: "KEY123", issuer_id: "issuer-1", pem: sample_pem, http: http)
  end

  def app_body(bundle_id)
    { data: [{ attributes: { bundleId: bundle_id, name: "X" } }] }.to_json
  end

  def id_body(identifier)
    { data: [{ attributes: { identifier: identifier } }] }.to_json
  end

  def test_check_passes_when_app_and_bundle_id_exist
    http, calls = fake_http(apps: { code: 200, body: app_body("com.acme.tattoo") },
                            ids: { code: 200, body: id_body("com.acme.tattoo") })
    assert_equal :ok, run_check(http).status
    assert_equal "com.acme.tattoo", calls.first[1]["filter[bundleId]"]
  end

  def test_check_blocks_on_a_rejected_key
    http, = fake_http(apps: { code: 401, body: "{}" })
    assert_equal :rejected, run_check(http).status
    http, = fake_http(apps: { code: 403, body: "{}" })
    assert_equal :rejected, run_check(http).status
  end

  def test_check_blocks_when_the_app_record_is_missing
    # Apple's filter also returns near matches, so the match must be exact.
    http, = fake_http(apps: { code: 200, body: app_body("com.acme.tattoo.beta") },
                      ids: { code: 200, body: id_body("com.acme.tattoo") })
    result = run_check(http)
    assert_equal :missing, result.status
    assert_equal 1, result.messages.size
    assert_includes result.messages.first, "App Store Connect"
  end

  def test_check_blocks_when_the_bundle_id_is_not_registered
    http, = fake_http(apps: { code: 200, body: app_body("com.acme.tattoo") })
    result = run_check(http)
    assert_equal :missing, result.status
    assert_includes result.messages.first, "not registered"
  end

  def test_check_does_not_block_on_network_trouble
    http, = fake_http(apps: { code: 503, body: "" })
    assert_equal :unknown, run_check(http).status
    failing = ->(_path, _query, _token) { raise SocketError, "no network" }
    assert_equal :unknown, run_check(failing).status
  end
end
