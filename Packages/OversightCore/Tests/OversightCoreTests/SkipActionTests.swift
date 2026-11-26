import XCTest
@testable import OversightCore

final class SkipActionTests: XCTestCase {
    func testSkipBackOnASinglePageSavesTheScreen() {
        XCTAssertEqual(skipAction(forward: false, pageCount: 1), .saveScreen)
    }

    func testSkipForwardOnASinglePageDoesNothing() {
        XCTAssertEqual(skipAction(forward: true, pageCount: 1), .nothing)
    }

    func testSkipsTurnPagesOfALongAnswer() {
        XCTAssertEqual(skipAction(forward: false, pageCount: 3), .turnPage(-1))
        XCTAssertEqual(skipAction(forward: true, pageCount: 3), .turnPage(1))
    }
}
