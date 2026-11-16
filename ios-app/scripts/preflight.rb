#!/usr/bin/env ruby
# frozen_string_literal: true

# Cheap check that runs on a Linux runner BEFORE the macOS build starts, so
# that a missing secret or a typo never costs macOS minutes.
#
#   ruby scripts/preflight.rb --lint   config file is well formed (run on every push)
#   ruby scripts/preflight.rb          config + secrets + a live check with Apple
#                                      (run only when a TestFlight build is about to start)
#
# Exit code 0 means "go ahead and build".

require_relative "../fastlane/app_config"

REQUIRED_SECRETS = {
  "ASC_KEY_ID" => "the Key ID of your App Store Connect API key",
  "ASC_ISSUER_ID" => "the Issuer ID shown above the API key list",
  "ASC_KEY_P8" => "the full text of the downloaded .p8 key file",
  "MATCH_PASSWORD" => "a password you make up, used to encrypt the signing files"
}.freeze

def annotate(level, message)
  # GitHub shows ::error:: and ::warning:: lines prominently on the run page.
  if ENV["GITHUB_ACTIONS"] == "true"
    puts "::#{level}::#{message.gsub("\n", ' ')}"
  else
    puts "#{level.upcase}: #{message}"
  end
end

def write_summary(lines)
  path = ENV["GITHUB_STEP_SUMMARY"]
  return if path.to_s.empty?

  File.open(path, "a") { |file| file.puts(lines.join("\n")) }
end

lint_only = ARGV.include?("--lint")

begin
  config = AppConfig.load
rescue AppConfig::Error => e
  annotate("error", e.message)
  exit 1
end

config_problems = AppConfig.problems(config)

if lint_only
  # On ordinary pushes placeholders are fine: they only block a real build.
  config_problems.each { |problem| annotate("warning", "Not ready for a TestFlight build yet: #{problem}") }
  puts "Config/App.xcconfig is well formed."
  exit 0
end

errors = config_problems.dup
warnings = []
notes = []

missing = REQUIRED_SECRETS.reject { |name, _| !ENV[name].to_s.strip.empty? }
missing.each do |name, description|
  errors << "GitHub secret #{name} is not set (#{description}). See docs/SETUP.md, step 4."
end

issuer_id = ENV["ASC_ISSUER_ID"].to_s.strip
if !issuer_id.empty? && !issuer_id.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  errors << "ASC_ISSUER_ID does not look like an Issuer ID. It has the form 12345678-abcd-1234-abcd-1234567890ab."
end

key_id = ENV["ASC_KEY_ID"].to_s.strip
if !key_id.empty? && !key_id.match?(/\A[A-Z0-9]{8,12}\z/)
  warnings << "ASC_KEY_ID looks unusual. It is normally about 10 capital letters and digits, like 2X9R4HXF34."
end

pem = nil
unless ENV["ASC_KEY_P8"].to_s.strip.empty?
  begin
    pem = AppConfig.normalize_p8(ENV["ASC_KEY_P8"])
  rescue AppConfig::Error => e
    errors << e.message
  end
end

if errors.empty? && pem
  check = AppConfig.check_apple(bundle_id: config.bundle_id, key_id: key_id, issuer_id: issuer_id, pem: pem)
  case check.status
  when :ok then notes.concat(check.messages)
  when :unknown then warnings.concat(check.messages.map { |message| "#{message} Continuing anyway." })
  else errors.concat(check.messages)
  end
end

notes.each { |note| puts note }
warnings.each { |warning| annotate("warning", warning) }
errors.each { |error| annotate("error", error) }

if errors.empty?
  write_summary(["### Ready to build", "", "App: `#{config.bundle_id}`, version #{config.marketing_version}."])
  puts "Preflight passed: starting the macOS build."
  exit 0
end

write_summary(
  ["### The TestFlight build did not start", "",
   "Nothing was built, so no macOS minutes were used. Fix the items below, then run the workflow again.", ""] +
  errors.map { |error| "- #{error}" }
)
puts "Preflight failed: the macOS build will not start."
exit 1
