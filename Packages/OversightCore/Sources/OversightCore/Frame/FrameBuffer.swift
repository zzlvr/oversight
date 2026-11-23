import Foundation

/// Holds only the most recent JPEG frame; older frames are dropped.
public final class FrameBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var frame: Data?

    public init() {}

    public func store(_ jpeg: Data) {
        lock.lock()
        frame = jpeg
        lock.unlock()
    }

    public func latest() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return frame
    }
}
