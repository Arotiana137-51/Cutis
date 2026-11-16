// swift-tools-version: 5.9
import PackageDescription

// Pure-Swift logic shared by the app: no UIKit, SwiftUI or ARKit in here,
// so its unit tests can run on Linux CI runners (which cost far less than macOS ones).
let package = Package(
    name: "AppCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
    ],
    targets: [
        .target(name: "AppCore"),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
    ]
)
