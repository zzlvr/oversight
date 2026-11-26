import Foundation

/// The last few frames with their times, to pick the one from just before the user left an app.
public final class RecentFrames {
    private let capacity: Int
    private var frames: [(date: Date, jpeg: Data)] = []

    public init(capacity: Int = 8) {
        self.capacity = capacity
    }

    public func add(_ jpeg: Data, at date: Date = Date()) {
        frames.append((date, jpeg))
        if frames.count > capacity { frames.removeFirst(frames.count - capacity) }
    }

    /// The newest frame not newer than `date`, or the oldest one kept.
    public func frame(before date: Date) -> Data? {
        (frames.last { $0.date <= date } ?? frames.first)?.jpeg
    }

    public func clear() {
        frames.removeAll()
    }
}
