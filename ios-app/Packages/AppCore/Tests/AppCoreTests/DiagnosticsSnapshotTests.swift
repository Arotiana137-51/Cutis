import XCTest
@testable import AppCore

final class DiagnosticsSnapshotTests: XCTestCase {

    private func makeSnapshot(
        deviceIdentifier: String = "iPhone16,1",
        sceneDepth: Bool = true,
        mesh: Bool = true
    ) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            appName: "Tattoo Preview",
            appVersion: "0.1.0",
            buildNumber: "202611160915",
            gitCommit: "abc1234",
            deviceIdentifier: deviceIdentifier,
            systemVersion: "iOS 18.1",
            worldTrackingSupported: true,
            sceneDepthSupported: sceneDepth,
            smoothedSceneDepthSupported: sceneDepth,
            meshReconstructionSupported: mesh,
            meshClassificationSupported: mesh
        )
    }

    func testLiDARIsAvailableWhenBothChecksPass() {
        let snapshot = makeSnapshot()
        XCTAssertEqual(snapshot.lidarStatus, .available)
        XCTAssertEqual(snapshot.lidarHeadline, "LiDAR: yes")
    }

    func testLiDARIsUnavailableWhenBothChecksFail() {
        let snapshot = makeSnapshot(sceneDepth: false, mesh: false)
        XCTAssertEqual(snapshot.lidarStatus, .unavailable)
        XCTAssertEqual(snapshot.lidarHeadline, "LiDAR: no")
    }

    func testLiDARIsPartialWhenTheChecksDisagree() {
        XCTAssertEqual(makeSnapshot(sceneDepth: true, mesh: false).lidarStatus, .partial)
        XCTAssertEqual(makeSnapshot(sceneDepth: false, mesh: true).lidarStatus, .partial)
        XCTAssertEqual(makeSnapshot(sceneDepth: true, mesh: false).lidarHeadline, "LiDAR: partial")
    }

    func testEveryStatusHasAnExplanation() {
        XCTAssertFalse(makeSnapshot().lidarExplanation.isEmpty)
        XCTAssertFalse(makeSnapshot(sceneDepth: false, mesh: false).lidarExplanation.isEmpty)
        XCTAssertFalse(makeSnapshot(sceneDepth: true, mesh: false).lidarExplanation.isEmpty)
    }

    func testReportListsEverythingNeededToDebugRemotely() {
        let expected = """
        Tattoo Preview diagnostics
        App: 0.1.0 (202611160915) commit abc1234
        Device: iPhone 15 Pro (iPhone16,1)
        System: iOS 18.1
        LiDAR: yes
        World tracking: yes
        Scene depth: yes
        Smoothed depth: yes
        Mesh reconstruction: yes
        Mesh classification: yes
        """
        XCTAssertEqual(makeSnapshot().report, expected)
    }

    func testReportForAnUnknownPhoneWithoutLiDAR() {
        let report = makeSnapshot(deviceIdentifier: "iPhone99,9", sceneDepth: false, mesh: false).report
        XCTAssertTrue(report.contains("Device: iPhone99,9\n"))
        XCTAssertTrue(report.contains("LiDAR: no\n"))
        XCTAssertTrue(report.contains("Scene depth: no\n"))
        XCTAssertTrue(report.contains("Mesh reconstruction: no\n"))
    }

    func testDeviceRowsShowWhenAModelIsNotInTheList() {
        let rows = makeSnapshot(deviceIdentifier: "iPhone99,9").deviceRows
        XCTAssertEqual(rows.first, DiagnosticsSnapshot.Row(label: "Model", value: "Not in list"))
        XCTAssertEqual(rows[1], DiagnosticsSnapshot.Row(label: "Model code", value: "iPhone99,9"))
    }

    func testRowCounts() {
        let snapshot = makeSnapshot()
        XCTAssertEqual(snapshot.appRows.count, 3)
        XCTAssertEqual(snapshot.deviceRows.count, 3)
        XCTAssertEqual(snapshot.capabilityRows.count, 5)
    }
}
