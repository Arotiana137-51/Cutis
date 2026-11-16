/// Everything the Phase 0 screen shows, captured once at launch.
///
/// The app fills this in from the device (bundle info, ARKit checks). This type
/// only holds the values and turns them into text, so it can be unit tested
/// without a phone.
public struct DiagnosticsSnapshot: Equatable, Sendable {

    /// Name shown under the app icon.
    public var appName: String
    /// Version shown to testers, for example "0.1.0".
    public var appVersion: String
    /// Build number set by CI, for example "202611160915".
    public var buildNumber: String
    /// Short git commit the build was made from.
    public var gitCommit: String
    /// Apple's model code, for example "iPhone16,1".
    public var deviceIdentifier: String
    /// Operating system name and version, for example "iOS 18.1".
    public var systemVersion: String
    /// `ARWorldTrackingConfiguration.isSupported`
    public var worldTrackingSupported: Bool
    /// `ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)`
    public var sceneDepthSupported: Bool
    /// `ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)`
    public var smoothedSceneDepthSupported: Bool
    /// `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`
    public var meshReconstructionSupported: Bool
    /// `ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)`
    public var meshClassificationSupported: Bool

    public init(
        appName: String,
        appVersion: String,
        buildNumber: String,
        gitCommit: String,
        deviceIdentifier: String,
        systemVersion: String,
        worldTrackingSupported: Bool,
        sceneDepthSupported: Bool,
        smoothedSceneDepthSupported: Bool,
        meshReconstructionSupported: Bool,
        meshClassificationSupported: Bool
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.gitCommit = gitCommit
        self.deviceIdentifier = deviceIdentifier
        self.systemVersion = systemVersion
        self.worldTrackingSupported = worldTrackingSupported
        self.sceneDepthSupported = sceneDepthSupported
        self.smoothedSceneDepthSupported = smoothedSceneDepthSupported
        self.meshReconstructionSupported = meshReconstructionSupported
        self.meshClassificationSupported = meshClassificationSupported
    }

    /// What the two LiDAR-only ARKit checks say, taken together.
    public enum LiDARStatus: Equatable, Sendable {
        /// Scene depth and mesh reconstruction are both supported.
        case available
        /// Neither is supported: this phone has no LiDAR sensor.
        case unavailable
        /// Only one of the two is supported. Not expected on any iPhone; worth reporting.
        case partial
    }

    public var lidarStatus: LiDARStatus {
        switch (sceneDepthSupported, meshReconstructionSupported) {
        case (true, true): return .available
        case (false, false): return .unavailable
        default: return .partial
        }
    }

    /// The headline of the Phase 0 screen: "LiDAR: yes".
    public var lidarHeadline: String {
        switch lidarStatus {
        case .available: return "LiDAR: yes"
        case .unavailable: return "LiDAR: no"
        case .partial: return "LiDAR: partial"
        }
    }

    /// One plain sentence explaining the headline.
    public var lidarExplanation: String {
        switch lidarStatus {
        case .available:
            return "This phone supports depth scanning and 3D mesh reconstruction."
        case .unavailable:
            return "This phone has no LiDAR sensor. It will use typed measurements instead of a scan."
        case .partial:
            return "Only one of the two LiDAR checks passed. Please send the diagnostics text."
        }
    }

    /// Model name with code, for example "iPhone 15 Pro (iPhone16,1)".
    public var deviceDisplayName: String {
        DeviceCatalog.displayName(forIdentifier: deviceIdentifier)
    }

    /// One label and value shown on screen and in the copied text.
    public struct Row: Equatable, Sendable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    /// The rows under "App" on the screen.
    public var appRows: [Row] {
        [
            Row(label: "Version", value: appVersion),
            Row(label: "Build", value: buildNumber),
            Row(label: "Commit", value: gitCommit),
        ]
    }

    /// The rows under "Device" on the screen.
    public var deviceRows: [Row] {
        [
            Row(label: "Model", value: DeviceCatalog.marketingName(forIdentifier: deviceIdentifier) ?? "Not in list"),
            Row(label: "Model code", value: deviceIdentifier),
            Row(label: "System", value: systemVersion),
        ]
    }

    /// The rows under "ARKit" on the screen.
    public var capabilityRows: [Row] {
        [
            Row(label: "World tracking", value: Self.yesNo(worldTrackingSupported)),
            Row(label: "Scene depth", value: Self.yesNo(sceneDepthSupported)),
            Row(label: "Smoothed depth", value: Self.yesNo(smoothedSceneDepthSupported)),
            Row(label: "Mesh reconstruction", value: Self.yesNo(meshReconstructionSupported)),
            Row(label: "Mesh classification", value: Self.yesNo(meshClassificationSupported)),
        ]
    }

    /// The text put on the clipboard by the "Copy diagnostics" button.
    public var report: String {
        var lines: [String] = []
        lines.append("\(appName) diagnostics")
        lines.append("App: \(appVersion) (\(buildNumber)) commit \(gitCommit)")
        lines.append("Device: \(deviceDisplayName)")
        lines.append("System: \(systemVersion)")
        lines.append(lidarHeadline)
        for row in capabilityRows {
            lines.append("\(row.label): \(row.value)")
        }
        return lines.joined(separator: "\n")
    }

    static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}
