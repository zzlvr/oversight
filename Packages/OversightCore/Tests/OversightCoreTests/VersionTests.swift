import XCTest
@testable import OversightCore

final class VersionTests: XCTestCase {
    func testCoreVersion() {
        XCTAssertEqual(coreVersion, "0.1.0")
    }
}
