import XCTest
import CoreGraphics
import ImageIO
@testable import OversightCore

final class FrameTests: XCTestCase {
    private func makeImage(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    private func dimensions(of jpeg: Data) -> (width: Int, height: Int) {
        let source = CGImageSourceCreateWithData(jpeg as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        return (props[kCGImagePropertyPixelWidth] as! Int, props[kCGImagePropertyPixelHeight] as! Int)
    }

    func testLatestIsNilInitially() {
        XCTAssertNil(FrameBuffer().latest())
    }

    func testLatestKeepsOnlyLastFrame() {
        let buffer = FrameBuffer()
        buffer.store(Data([1]))
        buffer.store(Data([2, 2]))
        XCTAssertEqual(buffer.latest(), Data([2, 2]))
    }

    func testJPEGDownscalesToMaxEdge() throws {
        let jpeg = try XCTUnwrap(downscaledJPEG(from: makeImage(width: 2000, height: 1000)))
        let size = dimensions(of: jpeg)
        XCTAssertEqual(size.width, 1280)
        XCTAssertEqual(size.height, 640)
    }

    func testPortraitImageIsLimitedByHeight() throws {
        let jpeg = try XCTUnwrap(downscaledJPEG(from: makeImage(width: 828, height: 1792)))
        let size = dimensions(of: jpeg)
        XCTAssertEqual(size.height, 1280)
        XCTAssertEqual(size.width, 591)
    }

    func testSmallImageIsNotUpscaled() throws {
        let jpeg = try XCTUnwrap(downscaledJPEG(from: makeImage(width: 400, height: 300)))
        let size = dimensions(of: jpeg)
        XCTAssertEqual(size.width, 400)
        XCTAssertEqual(size.height, 300)
    }
}
