import Foundation

public struct CapturedScreen: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let jpeg: Data
    public let date: Date
}

/// The last few screens seen in other apps, so the user can come back and ask about one of them.
/// Frames within `spacing` seconds of an entry's first frame replace that entry. Memory only.
public final class ScreenHistory {
    private let capacity: Int
    private let spacing: TimeInterval
    private var entries: [(started: Date, screen: CapturedScreen)] = []

    public init(capacity: Int = 6, spacing: TimeInterval = 2) {
        self.capacity = capacity
        self.spacing = spacing
    }

    /// Oldest first.
    public var screens: [CapturedScreen] { entries.map(\.screen) }

    public func add(_ jpeg: Data, at date: Date = Date()) {
        if let last = entries.last, date.timeIntervalSince(last.started) < spacing {
            entries[entries.count - 1].screen = CapturedScreen(id: last.screen.id, jpeg: jpeg, date: date)
            return
        }
        entries.append((date, CapturedScreen(id: UUID(), jpeg: jpeg, date: date)))
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    /// The newest screen not newer than `date`, or the oldest one kept.
    public func screen(before date: Date) -> CapturedScreen? {
        screens.last { $0.date <= date } ?? screens.first
    }

    public func clear() {
        entries.removeAll()
    }
}
