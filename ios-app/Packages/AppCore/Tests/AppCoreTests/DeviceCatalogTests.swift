import XCTest
@testable import AppCore

final class DeviceCatalogTests: XCTestCase {

    func testKnownIdentifierHasMarketingName() {
        XCTAssertEqual(DeviceCatalog.marketingName(forIdentifier: "iPhone13,3"), "iPhone 12 Pro")
        XCTAssertEqual(DeviceCatalog.marketingName(forIdentifier: "iPhone16,1"), "iPhone 15 Pro")
    }

    func testUnknownIdentifierHasNoMarketingName() {
        XCTAssertNil(DeviceCatalog.marketingName(forIdentifier: "iPhone99,9"))
        XCTAssertNil(DeviceCatalog.marketingName(forIdentifier: ""))
    }

    func testDisplayNameIncludesTheRawCode() {
        XCTAssertEqual(DeviceCatalog.displayName(forIdentifier: "iPhone15,3"), "iPhone 14 Pro Max (iPhone15,3)")
    }

    func testDisplayNameFallsBackToTheRawCode() {
        XCTAssertEqual(DeviceCatalog.displayName(forIdentifier: "iPhone99,9"), "iPhone99,9")
    }

    func testEveryEntryIsWellFormed() {
        for (identifier, name) in DeviceCatalog.names {
            XCTAssertTrue(identifier.hasPrefix("iPhone"), "\(identifier) should start with iPhone")
            XCTAssertTrue(identifier.contains(","), "\(identifier) should contain a comma")
            XCTAssertTrue(name.hasPrefix("iPhone"), "\(name) should start with iPhone")
        }
    }
}
