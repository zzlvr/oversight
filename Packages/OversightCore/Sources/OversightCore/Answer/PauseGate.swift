import Foundation

/// The Picture-in-Picture skip buttons can also report a pause. This tells a real pause press apart:
/// wait `settle` seconds after the pause, then ask only if no skip happened around it.
public struct PauseGate {
    public static let settle: TimeInterval = 0.5
    private var lastSkip: Date?

    public init() {}

    public mutating func skipped(at date: Date) {
        lastSkip = date
    }

    public func shouldAsk(pausedAt date: Date) -> Bool {
        guard let lastSkip else { return true }
        return abs(date.timeIntervalSince(lastSkip)) > 1
    }
}
