import Foundation

public struct CapturedScreen: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let jpeg: Data
    public let date: Date
}

/// The screens the user marked in other apps, so they can ask more about them. Memory only.
public final class ScreenHistory {
    private let capacity: Int
    public private(set) var screens: [CapturedScreen] = []

    public init(capacity: Int = 6) {
        self.capacity = capacity
    }

    /// Adds a screen, newest last. Marking the same frame twice keeps one copy.
    public func mark(_ jpeg: Data, at date: Date = Date()) {
        guard screens.last?.jpeg != jpeg else { return }
        screens.append(CapturedScreen(id: UUID(), jpeg: jpeg, date: date))
        if screens.count > capacity { screens.removeFirst(screens.count - capacity) }
    }

    public func clear() {
        screens.removeAll()
    }
}
