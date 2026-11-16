#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the project files that only a Mac can build, as far as Linux can:
# they parse, they have the keys the build needs, and every $(APP_...) value
# they refer to is defined in Config/App.xcconfig. Catching a typo here costs
# seconds on Linux instead of a failed macOS build.
#
# Run with: ruby scripts/lint.rb

require "json"
require "rexml/document"
require "yaml"
require_relative "../fastlane/app_config"

ROOT = File.expand_path("..", __dir__)
$failures = []

def check(description)
  problem = yield
  if problem
    $failures << "#{description}: #{problem}"
    puts "FAIL  #{description}: #{problem}"
  else
    puts "ok    #{description}"
  end
rescue StandardError => e
  $failures << "#{description}: #{e.class}: #{e.message}"
  puts "FAIL  #{description}: #{e.class}: #{e.message}"
end

def path(*parts)
  File.join(ROOT, *parts)
end

# Reads the top-level <dict> of a property list into a Ruby hash (strings, booleans, arrays, dicts).
def plist_value(element)
  case element.name
  when "dict"
    children = element.elements.to_a
    children.each_slice(2).to_h { |key, value| [key.text.to_s, plist_value(value)] }
  when "array" then element.elements.to_a.map { |child| plist_value(child) }
  when "true" then true
  when "false" then false
  else element.text.to_s
  end
end

xcconfig = AppConfig.parse(File.read(path("Config", "App.xcconfig"), encoding: "UTF-8"))
project_text = File.read(path("project.yml"), encoding: "UTF-8")
project = nil
info = nil

check("Config/App.xcconfig defines every app setting") do
  needed = %w[APP_DISPLAY_NAME APP_BUNDLE_ID APP_TEAM_ID APP_MARKETING_VERSION APP_BUILD_NUMBER APP_GIT_COMMIT]
  missing = needed - xcconfig.keys
  "missing #{missing.join(', ')}" unless missing.empty?
end

check("project.yml is valid YAML") do
  project = YAML.safe_load(project_text)
  "top level is not a mapping" unless project.is_a?(Hash)
end

check("project.yml describes the Cutis app target") do
  target = project.dig("targets", "Cutis")
  next "targets.Cutis is missing" unless target.is_a?(Hash)
  next "type must be application" unless target["type"] == "application"
  next "platform must be iOS" unless target["platform"] == "iOS"
  next "deployment target must be iOS 17.0" unless project.dig("options", "deploymentTarget", "iOS").to_s == "17.0"
  next "scheme Cutis is missing" unless project.dig("schemes", "Cutis", "build", "targets", "Cutis")

  nil
end

check("project.yml source folders and packages exist") do
  target = project.dig("targets", "Cutis")
  sources = Array(target["sources"]).map { |source| source.is_a?(Hash) ? source["path"] : source }
  missing = sources.reject { |source| File.directory?(path(source)) }
  packages = (project["packages"] || {}).map { |_name, package| package["path"] }.compact
  missing += packages.reject { |package| File.file?(path(package, "Package.swift")) }
  config_files = (project["configFiles"] || {}).values
  missing += config_files.reject { |file| File.file?(path(file)) }
  "not found: #{missing.join(', ')}" unless missing.empty?
end

check("Info.plist is a well-formed property list") do
  base = project.dig("targets", "Cutis", "settings", "base") || {}
  plist_path = path(base["INFOPLIST_FILE"].to_s)
  next "INFOPLIST_FILE #{base['INFOPLIST_FILE'].inspect} does not exist" unless File.file?(plist_path)

  document = REXML::Document.new(File.read(plist_path, encoding: "UTF-8"))
  info = plist_value(document.root.elements["dict"])
  nil
end

check("Info.plist has the keys App Store Connect requires") do
  needed = %w[
    CFBundleIdentifier CFBundleExecutable CFBundleShortVersionString CFBundleVersion CFBundleDisplayName
    NSCameraUsageDescription UILaunchScreen ITSAppUsesNonExemptEncryption UISupportedInterfaceOrientations
  ]
  missing = needed.reject { |key| info.key?(key) }
  next "missing #{missing.join(', ')}" unless missing.empty?
  next "ITSAppUsesNonExemptEncryption must be false" unless info["ITSAppUsesNonExemptEncryption"] == false
  next "NSCameraUsageDescription must explain the body scan" unless info["NSCameraUsageDescription"].match?(/scan/i)

  nil
end

check("every $(APP_...) value used by the project is defined in App.xcconfig") do
  used = (project_text + File.read(path("App", "Info.plist"))).scan(/\$\((APP_[A-Z_]+)\)/).flatten.uniq
  undefined = used - xcconfig.keys
  "undefined: #{undefined.join(', ')}" unless undefined.empty?
end

check("asset catalog files are valid JSON") do
  files = Dir.glob(path("App", "Resources", "**", "Contents.json"))
  next "no Contents.json files found" if files.empty?

  files.each { |file| JSON.parse(File.read(file)) }
  nil
end

check("colours named in Info.plist and project.yml exist in the asset catalog") do
  base = project.dig("targets", "Cutis", "settings", "base") || {}
  names = [info.dig("UILaunchScreen", "UIColorName"), base["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"]].compact
  missing = names.reject { |name| File.file?(path("App", "Resources", "Assets.xcassets", "#{name}.colorset", "Contents.json")) }
  "missing colour sets: #{missing.join(', ')}" unless missing.empty?
end

check("app icon is a 1024x1024 PNG without transparency") do
  base = project.dig("targets", "Cutis", "settings", "base") || {}
  icon_dir = path("App", "Resources", "Assets.xcassets", "#{base['ASSETCATALOG_COMPILER_APPICON_NAME']}.appiconset")
  contents = JSON.parse(File.read(File.join(icon_dir, "Contents.json")))
  filename = contents["images"].map { |image| image["filename"] }.compact.first
  next "no icon file listed" if filename.nil?

  header = File.binread(File.join(icon_dir, filename), 26)
  next "not a PNG file" unless header.start_with?("\x89PNG\r\n\x1A\n".b)

  width, height = header[16, 8].unpack("NN")
  colour_type = header[25].ord
  next "is #{width}x#{height}, must be 1024x1024" unless [width, height] == [1024, 1024]
  # PNG colour types 4 and 6 carry an alpha channel, which App Store Connect rejects.
  next "has an alpha channel (transparency)" if [4, 6].include?(colour_type)

  nil
end

check("Swift sources exist for the app and the package") do
  app = Dir.glob(path("App", "**", "*.swift"))
  package = Dir.glob(path("Packages", "AppCore", "Sources", "**", "*.swift"))
  next "no Swift files under App/" if app.empty?
  next "no Swift files under Packages/AppCore/Sources" if package.empty?
  next "no @main entry point under App/" unless app.any? { |file| File.read(file).include?("@main") }

  nil
end

if $failures.empty?
  puts "\nAll project checks passed."
else
  puts "\n#{$failures.size} problem(s) found."
  $failures.each { |failure| puts "::error::#{failure}" } if ENV["GITHUB_ACTIONS"] == "true"
  exit 1
end
