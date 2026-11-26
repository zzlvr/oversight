import AVKit
import SwiftUI
import UIKit
import OversightCore

/// Shows text in a Picture-in-Picture window by rendering it into video frames.
/// All methods must be called on the main thread.
final class AnswerWindow: NSObject, ObservableObject, AVPictureInPictureSampleBufferPlaybackDelegate, AVPictureInPictureControllerDelegate {
    let displayLayer = AVSampleBufferDisplayLayer()
    @Published var failure: String?
    @Published var isActive = false
    var onPlayPause: (() -> Void)?

    private var controller: AVPictureInPictureController?
    private var timebase: CMTimebase?
    private var timer: Timer?
    private var screens = ["Oversight"]
    private var index = 0
    private var shownSince = Date()
    private var gate = PauseGate()

    func prepare() {
        guard controller == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        displayLayer.videoGravity = .resizeAspect
        var created: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &created)
        guard let timebase = created else { return }
        self.timebase = timebase
        displayLayer.controlTimebase = timebase
        CMTimebaseSetTime(timebase, time: .zero)
        CMTimebaseSetRate(timebase, rate: 1)
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer, playbackDelegate: self)
        let pip = AVPictureInPictureController(contentSource: source)
        pip.delegate = self
        pip.canStartPictureInPictureAutomaticallyFromInline = true
        controller = pip
        render()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    func start() {
        prepare()
        failure = nil
        controller?.startPictureInPicture()
    }

    func show(_ text: String) {
        let split = pages(for: text, lineWidth: 34, linesPerPage: 7)
        screens = split.isEmpty ? [""] : split
        index = 0
        shownSince = Date()
        render()
    }

    private func turnPage(by step: Int) {
        index = (index + step + screens.count) % screens.count
        shownSince = Date()
        render()
    }

    private func tick() {
        if screens.count > 1, Date().timeIntervalSince(shownSince) >= 7 {
            turnPage(by: 1)
        } else {
            render()
        }
    }

    private func render() {
        guard let timebase, let buffer = makeBuffer(time: CMTimebaseGetTime(timebase)) else { return }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(buffer)
    }

    private func makeBuffer(time: CMTime) -> CMSampleBuffer? {
        let size = CGSize(width: 640, height: 360)
        var created: CVPixelBuffer?
        // IOSurface backing is required: the window is drawn by another process.
        let attributes = [kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                          kCVPixelBufferCGImageCompatibilityKey as String: true,
                          kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as [String: Any]
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32BGRA, attributes as CFDictionary, &created)
        guard let pixelBuffer = created else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        (screens[index] as NSString).draw(
            in: CGRect(x: 14, y: 8, width: size.width - 28, height: 316),
            withAttributes: [.font: UIFont.systemFont(ofSize: 32), .foregroundColor: UIColor.white])
        if screens.count > 1 {
            ("\(index + 1)/\(screens.count)" as NSString).draw(
                at: CGPoint(x: size.width - 70, y: size.height - 32),
                withAttributes: [.font: UIFont.systemFont(ofSize: 22), .foregroundColor: UIColor.lightGray])
        }
        UIGraphicsPopContext()

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &format)
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sample)
        return sample
    }

    // MARK: AVPictureInPictureSampleBufferPlaybackDelegate

    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {
        let pressed = Date()
        DispatchQueue.main.async { c.invalidatePlaybackState() }
        guard !playing else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + PauseGate.settle) {
            if self.gate.shouldAsk(pausedAt: pressed) { self.onPlayPause?() }
        }
    }

    // A finite range around "now" so that the skip buttons are offered.
    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        let now = timebase.map { CMTimebaseGetTime($0) } ?? .zero
        return CMTimeRange(start: CMTimeSubtract(now, CMTime(seconds: 1800, preferredTimescale: 600)),
                           duration: CMTime(seconds: 3600, preferredTimescale: 600))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { false }

    func pictureInPictureController(_ c: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ c: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        let step = skipInterval.seconds >= 0 ? 1 : -1
        let pressed = Date()
        DispatchQueue.main.async {
            self.gate.skipped(at: pressed)
            self.turnPage(by: step)
        }
        completionHandler()
    }

    // MARK: AVPictureInPictureControllerDelegate

    func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
        DispatchQueue.main.async { self.isActive = true }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        DispatchQueue.main.async { self.isActive = false }
    }

    func pictureInPictureController(_ c: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DispatchQueue.main.async { self.failure = error.localizedDescription }
    }
}

struct AnswerLayerView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer
    func makeUIView(context: Context) -> LayerHost { LayerHost(layer: layer) }
    func updateUIView(_ uiView: LayerHost, context: Context) {}
}

final class LayerHost: UIView {
    private let hosted: CALayer
    init(layer: CALayer) {
        hosted = layer
        super.init(frame: .zero)
        self.layer.addSublayer(layer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func layoutSubviews() {
        super.layoutSubviews()
        hosted.frame = bounds
    }
}
