import CoreGraphics
import Foundation
import ImageIO

public struct CapturedScreen: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let jpeg: Data
    public let date: Date
}

/// A tiny greyscale version of a frame, used to tell whether the screen changed.
public func screenSignature(of jpeg: Data) -> [UInt8]? {
    let width = 16, height = 32
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return false }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return drawn ? pixels : nil
}

/// Small differences (a clock, a changing line of text) still count as the same screen.
public func looksTheSame(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    guard a.count == b.count, !a.isEmpty else { return false }
    let total = zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
    return total / a.count < 8
}

/// The last few screens seen in other apps, so the user can come back and ask about one of them.
/// A screen is kept only once it has stayed still, which leaves out app switching and scrolling.
/// Memory only.
public final class ScreenHistory {
    private let capacity: Int
    private let settle: TimeInterval
    private var entries: [(signature: [UInt8], screen: CapturedScreen)] = []
    private var current: (signature: [UInt8], since: Date)?

    public init(capacity: Int = 6, settle: TimeInterval = 1.5) {
        self.capacity = capacity
        self.settle = settle
    }

    /// Oldest first.
    public var screens: [CapturedScreen] { entries.map(\.screen) }

    public func add(_ jpeg: Data, signature: [UInt8], at date: Date = Date()) {
        guard let current, looksTheSame(current.signature, signature) else {
            current = (signature, date)
            return
        }
        self.current = (signature, current.since)
        guard date.timeIntervalSince(current.since) >= settle else { return }

        if let last = entries.last, looksTheSame(last.signature, signature) {
            entries[entries.count - 1] = (signature, CapturedScreen(id: last.screen.id, jpeg: jpeg, date: date))
        } else {
            entries.append((signature, CapturedScreen(id: UUID(), jpeg: jpeg, date: date)))
            if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
        }
    }

    public func clear() {
        entries.removeAll()
        current = nil
    }
}
