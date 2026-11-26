import ReplayKit
import CoreImage
import OversightCore

/// Passes the latest screen frame to the app. Nothing is stored or sent anywhere else.
final class SampleHandler: RPBroadcastSampleHandler {
    private let context = CIContext()
    private var lastSend = Date.distantPast
    private let sender = FrameSender(
        identity: .load(from: KeychainStore(service: "com.zzlvr.oversight.broadcast")),
        pins: PinStore(
        load: { UserDefaults.standard.data(forKey: "pinnedAppKey") },
        save: { UserDefaults.standard.set($0, forKey: "pinnedAppKey") }))

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              Date().timeIntervalSince(lastSend) >= 0.5,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        lastSend = Date()
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = min(1, 1280 / max(image.extent.width, image.extent.height))
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(small, from: small.extent),
              let jpeg = downscaledJPEG(from: cgImage)
        else { return }
        sender.send(jpeg)
    }

    override func broadcastFinished() {
        // An empty payload tells the app to forget the last frame.
        let done = DispatchSemaphore(value: 0)
        sender.send(Data()) { _ in done.signal() }
        _ = done.wait(timeout: .now() + 1)
    }
}
