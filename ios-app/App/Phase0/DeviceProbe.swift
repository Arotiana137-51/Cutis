import ARKit
import AppCore
import Foundation

/// Reads the facts shown on the Phase 0 screen from the device.
///
/// These ARKit checks only ask what the hardware supports. They do not start
/// the camera, so no permission prompt appears in Phase 0.
enum DeviceProbe {

    @MainActor
    static func snapshot() -> DiagnosticsSnapshot {
        let bundle = Bundle.main

        return DiagnosticsSnapshot(
            appName: infoString("CFBundleDisplayName", in: bundle),
            appVersion: infoString("CFBundleShortVersionString", in: bundle),
            buildNumber: infoString("CFBundleVersion", in: bundle),
            gitCommit: infoString("CutisGitCommit", in: bundle),
            deviceIdentifier: modelIdentifier(),
            systemVersion: systemVersion(),
            worldTrackingSupported: ARWorldTrackingConfiguration.isSupported,
            sceneDepthSupported: ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth),
            smoothedSceneDepthSupported: ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth),
            meshReconstructionSupported: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
            meshClassificationSupported: ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        )
    }

    private static func infoString(_ key: String, in bundle: Bundle) -> String {
        let value = bundle.object(forInfoDictionaryKey: key) as? String
        return value ?? "unknown"
    }

    /// Operating system version, for example "iOS 18.1".
    private static func systemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var text = "iOS \(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion > 0 {
            text += ".\(version.patchVersion)"
        }
        return text
    }

    /// Apple's model code for this device, for example "iPhone16,1".
    private static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        var identifier = ""
        for child in mirror.children {
            guard let value = child.value as? Int8, value != 0 else {
                break
            }
            identifier.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }
}
