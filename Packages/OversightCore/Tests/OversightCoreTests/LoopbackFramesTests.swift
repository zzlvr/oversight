import XCTest
@testable import OversightCore

final class LoopbackFramesTests: XCTestCase {
    private final class Pin {
        var key: Data?
        var store: PinStore { PinStore(load: { self.key }, save: { self.key = $0 }) }
    }

    private func startReceiver(_ identity: FrameIdentity, port: UInt16,
                               onFrame: @escaping (Data) -> Void = { _ in },
                               onEnd: @escaping () -> Void = {}) -> FrameReceiver {
        let receiver = FrameReceiver(identity: identity)
        let ready = expectation(description: "listener ready \(port)")
        receiver.start(port: port, onState: { if $0 == .ready { ready.fulfill() } },
                       onFrame: onFrame, onEnd: onEnd)
        wait(for: [ready], timeout: 5)
        return receiver
    }

    private func send(_ payload: Data, port: UInt16, pin: Pin) -> Bool {
        let done = expectation(description: "send finished \(port)")
        var result = false
        FrameSender(port: port, pins: pin.store).send(payload) { result = $0; done.fulfill() }
        wait(for: [done], timeout: 8)
        return result
    }

    func testFrameArrivesIntactAndKeyIsPinned() {
        let identity = FrameIdentity()
        let received = expectation(description: "frame")
        let frame = Data((0..<300_000).map { UInt8($0 % 251) })
        var got = Data()
        let receiver = startReceiver(identity, port: 47991, onFrame: { got = $0; received.fulfill() })
        let pin = Pin()

        XCTAssertTrue(send(frame, port: 47991, pin: pin))
        wait(for: [received], timeout: 5)
        receiver.stop()

        XCTAssertEqual(got, frame)
        XCTAssertEqual(pin.key, identity.publicKey)
    }

    func testReceiverWithAnotherKeyGetsNoFrame() {
        let pin = Pin()
        pin.key = FrameIdentity().publicKey
        let leaked = expectation(description: "frame must not arrive")
        leaked.isInverted = true
        let impostor = startReceiver(FrameIdentity(), port: 47992, onFrame: { _ in leaked.fulfill() })

        XCTAssertFalse(send(Data([1, 2, 3]), port: 47992, pin: pin))
        wait(for: [leaked], timeout: 1)
        impostor.stop()
    }

    func testEmptyPayloadSignalsEndOfBroadcast() {
        let ended = expectation(description: "end")
        let receiver = startReceiver(FrameIdentity(), port: 47993,
                                     onFrame: { _ in XCTFail("no frame expected") },
                                     onEnd: { ended.fulfill() })
        XCTAssertTrue(send(Data(), port: 47993, pin: Pin()))
        wait(for: [ended], timeout: 5)
        receiver.stop()
    }

    func testSendFailsWhenNobodyIsListening() {
        XCTAssertFalse(send(Data([1]), port: 47994, pin: Pin()))
    }

    func testIdentityIsStableInKeychain() {
        let keychain = KeychainStore(service: "oversight.tests.\(UUID().uuidString)")
        let first = FrameIdentity.load(from: keychain)
        let second = FrameIdentity.load(from: keychain)
        XCTAssertEqual(first.publicKey, second.publicKey)
        keychain.remove("frame-identity")
    }
}
