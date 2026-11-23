import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Scales `image` so its longer side is at most `maxLongEdge` (never upscales) and encodes it as JPEG.
public func downscaledJPEG(from image: CGImage, maxLongEdge: Int = 1280, quality: Double = 0.6) -> Data? {
    let longEdge = max(image.width, image.height)
    let scale = longEdge > maxLongEdge ? Double(maxLongEdge) / Double(longEdge) : 1
    let width = max(1, Int((Double(image.width) * scale).rounded()))
    let height = max(1, Int((Double(image.height) * scale).rounded()))

    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let scaled = context.makeImage() else { return nil }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        output, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(
        destination, scaled,
        [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
}
