import SwiftUI

/// App entry point. Phase 0 has a single screen that proves the build
/// pipeline works and reports whether this phone has LiDAR.
@main
struct CutisApp: App {
    var body: some Scene {
        WindowGroup {
            PipelineProofView(snapshot: DeviceProbe.snapshot())
                .preferredColorScheme(.dark)
        }
    }
}
