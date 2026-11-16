# frozen_string_literal: true

# Reads and checks the app identity in Config/App.xcconfig.
#
# Used in two places so they can never disagree:
#   - fastlane/Fastfile       (the macOS build that signs and uploads the app)
#   - scripts/preflight.rb    (a cheap Linux check that runs before the macOS build)
#
# Only Ruby's standard library is used, so the Linux check needs no gems installed.

require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module AppConfig
  CONFIG_PATH = File.expand_path("../Config/App.xcconfig", __dir__)

  # The branch of this repository where fastlane match keeps the encrypted
  # signing certificate and provisioning profile.
  SIGNING_BRANCH = "ios-signing"

  Values = Struct.new(:display_name, :bundle_id, :team_id, :marketing_version, keyword_init: true)

  REQUIRED_KEYS = {
    "APP_DISPLAY_NAME" => :display_name,
    "APP_BUNDLE_ID" => :bundle_id,
    "APP_TEAM_ID" => :team_id,
    "APP_MARKETING_VERSION" => :marketing_version
  }.freeze

  class Error < StandardError; end

  # Turns the text of an .xcconfig file into a { "KEY" => "value" } hash.
  # Understands `KEY = value` lines and `//` comments, which is all we use.
  def self.parse(text)
    settings = {}
    text.each_line do |line|
      line = line.sub(%r{//.*\z}m, "").strip
      next if line.empty? || line.start_with?("#")

      key, value = line.split("=", 2)
      next if value.nil?

      settings[key.strip] = value.strip
    end
    settings
  end

  # Reads the config file and returns its values. Raises if a line is missing.
  def self.load(path = CONFIG_PATH)
    raise Error, "Config file not found: #{path}" unless File.file?(path)

    settings = parse(File.read(path, encoding: "UTF-8"))
    missing = REQUIRED_KEYS.keys.reject { |key| settings.key?(key) }
    raise Error, "#{File.basename(path)} is missing: #{missing.join(', ')}" unless missing.empty?

    Values.new(**REQUIRED_KEYS.to_h { |key, field| [field, settings[key]] })
  end

  # Returns a list of plain-language problems. Empty means the config is ready to build.
  def self.problems(values)
    found = []

    found << "APP_DISPLAY_NAME is empty. Set the name shown under the app icon." if values.display_name.to_s.empty?

    bundle_id = values.bundle_id.to_s
    if bundle_id.empty? || bundle_id.include?("PLACEHOLDER")
      found << "APP_BUNDLE_ID is still the placeholder. Put your real bundle ID there (docs/SETUP.md, step 5)."
    elsif !bundle_id.match?(/\A[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+\z/)
      found << "APP_BUNDLE_ID \"#{bundle_id}\" is not a valid bundle ID. " \
               "Use letters, digits, hyphens and dots only, like com.yourname.tattoopreview."
    elsif bundle_id.start_with?("com.example.", "com.yourname.")
      found << "APP_BUNDLE_ID \"#{bundle_id}\" is the example value. Use the bundle ID you registered with Apple."
    end

    team_id = values.team_id.to_s
    if team_id.empty? || team_id.include?("PLACEHOLDER")
      found << "APP_TEAM_ID is still the placeholder. Put your Apple Team ID there (docs/SETUP.md, step 5)."
    elsif !team_id.match?(/\A[A-Z0-9]{10}\z/)
      found << "APP_TEAM_ID \"#{team_id}\" does not look like a Team ID. It is exactly 10 capital letters and digits."
    elsif team_id == "A1B2C3D4E5"
      found << "APP_TEAM_ID is the example value. Use your own Team ID."
    end

    unless values.marketing_version.to_s.match?(/\A\d+(\.\d+){0,2}\z/)
      found << "APP_MARKETING_VERSION \"#{values.marketing_version}\" must look like 0.1.0 (numbers and dots)."
    end

    found
  end

  # The provisioning profile name fastlane match creates for an App Store build.
  # project.yml uses the same name, so the two must stay in step.
  def self.profile_name(bundle_id)
    "match AppStore #{bundle_id}"
  end

  # ── App Store Connect API key ──────────────────────────────────────────────

  # Accepts the .p8 key as pasted into the GitHub secret: either the plain text
  # of the file, or that text encoded as base64. Returns clean PEM text.
  def self.normalize_p8(raw)
    text = raw.to_s.gsub("\r\n", "\n").gsub("\\n", "\n").strip
    raise Error, "The App Store Connect key (ASC_KEY_P8) is empty." if text.empty?

    unless text.include?("BEGIN")
      decoded = begin
        Base64.decode64(text).force_encoding("UTF-8")
      rescue StandardError
        ""
      end
      text = decoded.gsub("\r\n", "\n").strip if decoded.valid_encoding? && decoded.include?("BEGIN")
    end

    unless text.include?("BEGIN PRIVATE KEY") && text.include?("END PRIVATE KEY")
      raise Error, "ASC_KEY_P8 does not look like a .p8 key file. Paste the whole file, including the " \
                   "-----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY----- lines."
    end

    begin
      OpenSSL::PKey.read(text)
    rescue StandardError => e
      raise Error, "ASC_KEY_P8 could not be read as a private key (#{e.message}). " \
                   "Paste the .p8 file again, unchanged."
    end

    "#{text}\n"
  end

  # Builds the short-lived signed token Apple's API expects (JWT, ES256).
  def self.api_token(key_id:, issuer_id:, pem:, now: Time.now.to_i)
    header = { alg: "ES256", kid: key_id, typ: "JWT" }
    payload = { iss: issuer_id, iat: now - 30, exp: now + 600, aud: "appstoreconnect-v1" }
    signing_input = [header, payload].map { |part| base64url(JSON.generate(part)) }.join(".")

    der = OpenSSL::PKey.read(pem).sign(OpenSSL::Digest.new("SHA256"), signing_input)
    # OpenSSL returns the signature wrapped (ASN.1 DER); a JWT wants the two raw 32-byte numbers.
    raw = OpenSSL::ASN1.decode(der).value.map { |number| number.value.to_s(2).rjust(32, "\x00".b) }.join

    "#{signing_input}.#{base64url(raw)}"
  end

  def self.base64url(data)
    Base64.urlsafe_encode64(data, padding: false)
  end

  # Result of asking Apple about this app. `status` is one of:
  #   :ok          everything needed for a build exists
  #   :rejected    Apple refused the key (blocking)
  #   :missing     the key works but something is not set up yet (blocking)
  #   :unknown     could not check (network trouble or an unexpected answer; not blocking)
  AppleCheck = Struct.new(:status, :messages, keyword_init: true)

  # Asks App Store Connect whether the key works, the bundle ID is registered
  # and the app record exists. Costs nothing and takes a couple of seconds.
  def self.check_apple(bundle_id:, key_id:, issuer_id:, pem:, http: method(:http_get))
    token = api_token(key_id: key_id, issuer_id: issuer_id, pem: pem)

    apps = http.call("/v1/apps", { "filter[bundleId]" => bundle_id, "fields[apps]" => "bundleId,name", "limit" => "200" }, token)
    case apps[:code]
    when 200
      # carry on
    when 401
      return AppleCheck.new(status: :rejected, messages: [
        "Apple rejected the API key (HTTP 401). Check that ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 " \
        "all come from the same key, and that the key has not been revoked (docs/SETUP.md, step 3)."
      ])
    when 403
      return AppleCheck.new(status: :rejected, messages: [
        "Apple says this API key is not allowed to list apps (HTTP 403). Create a new key with the " \
        "Admin role (docs/SETUP.md, step 3). Also check for unsigned agreements in App Store Connect."
      ])
    else
      return AppleCheck.new(status: :unknown, messages: ["Could not check the app record (HTTP #{apps[:code]})."])
    end

    messages = []
    app_found = records(apps).any? { |record| record.dig("attributes", "bundleId") == bundle_id }
    unless app_found
      messages << "No app with bundle ID \"#{bundle_id}\" exists in App Store Connect yet. " \
                  "Create the app record (docs/SETUP.md, step 2)."
    end

    ids = http.call("/v1/bundleIds", { "filter[identifier]" => bundle_id, "fields[bundleIds]" => "identifier", "limit" => "200" }, token)
    if ids[:code] == 200
      id_found = records(ids).any? { |record| record.dig("attributes", "identifier") == bundle_id }
      unless id_found
        messages << "The bundle ID \"#{bundle_id}\" is not registered in your Apple Developer account. " \
                    "Register it (docs/SETUP.md, step 1) or fix APP_BUNDLE_ID so it matches exactly."
      end
    elsif messages.empty?
      return AppleCheck.new(status: :unknown, messages: ["Could not check the bundle ID (HTTP #{ids[:code]})."])
    end

    return AppleCheck.new(status: :missing, messages: messages) unless messages.empty?

    AppleCheck.new(status: :ok, messages: ["Apple accepted the API key and found the app \"#{bundle_id}\"."])
  rescue Error => e
    AppleCheck.new(status: :rejected, messages: [e.message])
  rescue StandardError => e
    AppleCheck.new(status: :unknown, messages: ["Could not reach App Store Connect (#{e.class}: #{e.message})."])
  end

  def self.records(response)
    data = JSON.parse(response[:body].to_s)["data"]
    data.is_a?(Array) ? data : []
  rescue JSON::ParserError
    []
  end

  def self.http_get(path, query, token)
    uri = URI("https://api.appstoreconnect.apple.com#{path}")
    uri.query = URI.encode_www_form(query)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |connection|
      connection.request(request)
    end
    { code: response.code.to_i, body: response.body }
  end
end
