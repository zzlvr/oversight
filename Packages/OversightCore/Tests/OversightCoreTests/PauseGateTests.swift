import XCTest
@testable import OversightCore

final class PauseGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 5_000)

    func testPauseAloneAsks() {
        XCTAssertTrue(PauseGate().shouldAsk(pausedAt: now))
    }

    func testPauseSentRightAfterASkipDoesNotAsk() {
        var gate = PauseGate()
        gate.skipped(at: now)
        XCTAssertFalse(gate.shouldAsk(pausedAt: now + 0.2))
    }

    func testPauseSentRightBeforeASkipDoesNotAsk() {
        var gate = PauseGate()
        gate.skipped(at: now + 0.2)
        XCTAssertFalse(gate.shouldAsk(pausedAt: now))
    }

    func testPauseLongAfterASkipAsks() {
        var gate = PauseGate()
        gate.skipped(at: now)
        XCTAssertTrue(gate.shouldAsk(pausedAt: now + 3))
    }
}
