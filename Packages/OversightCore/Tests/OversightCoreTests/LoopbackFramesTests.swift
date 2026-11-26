import Network
import XCTest
@testable import OversightCore

final class LoopbackFramesTests: XCTestCase {
    private final class Pin {
        var key: Data?
        var store: PinStore { PinStore(load: { self.key }, save: { self.key = $0 }) }
    }

    private func startReceiver(_ identity: FrameIdentity = FrameIdentity(), senders: Pin = Pin(), port: UInt16,
                               deadline: TimeInterval = 5,
                               onFrame: @escaping (Data) -> Void = { _ in },
                               onEnd: @escaping () -> Void = {}) -> FrameReceiver {
        let receiver = FrameReceiver(identity: identity, senders: senders.store, deadline: deadline)
        let ready = expectation(description: "listener ready \(port)")
        receiver.start(port: port, onState: { if $0 == .ready { ready.fulfill() } },
                       onFrame: onFrame, onEnd: onEnd)
        wait(for: [ready], timeout: 5)
        return receiver
    }

    private func send(_ payload: Data, port: UInt16, pin: Pin = Pin(), identity: FrameIdentity = FrameIdentity()) -> Bool {
        let done = expectation(description: "send finished \(port)")
        var result = false
        FrameSender(port: port, identity: identity, pins: pin.store).send(payload) { result = $0; done.fulfill() }
        wait(for: [done], timeout: 8)
        return result
    }

    private func neverCalled(_ description: String) -> XCTestExpectation {
        let expectation = expectation(description: description)
        expectation.isInverted = true
        return expectation
    }

    func testFrameArrivesIntactAndBothSidesRememberEachOther() {
        let app = FrameIdentity(), extensionIdentity = FrameIdentity()
        let appPin = Pin(), senderPin = Pin()
        let received = expectation(description: "frame")
        let frame = Data((0..<300_000).map { UInt8($0 % 251) })
        var got = Data()
        let receiver = startReceiver(app, senders: senderPin, port: 47991, onFrame: { got = $0; received.fulfill() })

        XCTAssertTrue(send(frame, port: 47991, pin: appPin, identity: extensionIdentity))
        wait(for: [received], timeout: 5)
        receiver.stop()

        XCTAssertEqual(got, frame)
        XCTAssertEqual(appPin.key, app.publicKey)
        XCTAssertEqual(senderPin.key, extensionIdentity.publicKey)
    }

    func testReceiverWithAnotherKeyGetsNoFrame() {
        let pin = Pin()
        pin.key = FrameIdentity().publicKey
        let leaked = neverCalled("frame must not leak")
        let impostor = startReceiver(port: 47992, onFrame: { _ in leaked.fulfill() })

        XCTAssertFalse(send(Data([1, 2, 3]), port: 47992, pin: pin))
        wait(for: [leaked], timeout: 1)
        impostor.stop()
    }

    func testFrameFromAnotherSenderIsRejected() {
        let senders = Pin()
        senders.key = FrameIdentity().publicKey
        let accepted = neverCalled("foreign frame accepted")
        let ended = neverCalled("foreign end accepted")
        let receiver = startReceiver(senders: senders, port: 47996,
                                     onFrame: { _ in accepted.fulfill() }, onEnd: { ended.fulfill() })

        _ = send(Data([1, 2, 3]), port: 47996)
        _ = send(Data(), port: 47996)
        wait(for: [accepted, ended], timeout: 1)
        receiver.stop()
    }

    func testUnsignedDataIsIgnored() {
        let accepted = neverCalled("unsigned frame accepted")
        let senders = Pin()
        let receiver = startReceiver(senders: senders, port: 47997, onFrame: { _ in accepted.fulfill() })

        let connection = NWConnection(host: "127.0.0.1", port: 47997, using: .tcp)
        connection.start(queue: DispatchQueue(label: "raw"))
        connection.send(content: Data(repeating: 7, count: 32), completion: .contentProcessed { _ in })
        connection.receive(minimumIncompleteLength: 160, maximumLength: 160) { _, _, _, _ in
            connection.send(content: Data(repeating: 9, count: 500), contentContext: .finalMessage,
                            isComplete: true, completion: .contentProcessed { _ in })
        }
        wait(for: [accepted], timeout: 1.5)
        connection.cancel()
        receiver.stop()
        XCTAssertNil(senders.key)
    }

    func testIdleConnectionIsClosedAfterTheDeadline() {
        let receiver = startReceiver(port: 47998, deadline: 0.5)
        let closed = expectation(description: "closed by receiver")
        let connection = NWConnection(host: "127.0.0.1", port: 47998, using: .tcp)
        connection.start(queue: DispatchQueue(label: "idle"))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 10) { _, _, isComplete, error in
            if isComplete || error != nil { closed.fulfill() }
        }
        wait(for: [closed], timeout: 4)
        connection.cancel()
        receiver.stop()
    }

    func testAnotherListenerCannotTakeTheSamePort() {
        let first = startReceiver(port: 47999)
        let second = FrameReceiver(identity: FrameIdentity(), senders: Pin().store)
        let refused = expectation(description: "second listener refused")
        let accepted = neverCalled("second listener became ready")
        second.start(port: 47999, onState: { state in
            if case .failed = state { refused.fulfill() } else { accepted.fulfill() }
        }, onFrame: { _ in }, onEnd: {})
        wait(for: [refused, accepted], timeout: 3)
        first.stop()
        second.stop()
    }

    func testEmptyPayloadSignalsEndOfBroadcast() {
        let ended = expectation(description: "end")
        let receiver = startReceiver(port: 47993,
                                     onFrame: { _ in XCTFail("no frame expected") },
                                     onEnd: { ended.fulfill() })
        XCTAssertTrue(send(Data(), port: 47993))
        wait(for: [ended], timeout: 5)
        receiver.stop()
    }

    func testEndSignalIsNotDroppedWhileAFrameIsInFlight() {
        let ended = expectation(description: "end")
        let endSent = expectation(description: "end sent")
        let receiver = startReceiver(port: 47995, onEnd: { ended.fulfill() })
        let sender = FrameSender(port: 47995, identity: FrameIdentity(), pins: Pin().store)

        sender.send(Data(count: 2_000_000))
        sender.send(Data()) { success in
            XCTAssertTrue(success)
            endSent.fulfill()
        }
        wait(for: [endSent, ended], timeout: 8)
        receiver.stop()
    }

    func testSendFailsWhenNobodyIsListening() {
        XCTAssertFalse(send(Data([1]), port: 47994))
    }

    func testIdentityIsStableInKeychain() {
        let keychain = KeychainStore(service: "oversight.tests.\(UUID().uuidString)")
        let first = FrameIdentity.load(from: keychain)
        let second = FrameIdentity.load(from: keychain)
        XCTAssertEqual(first.publicKey, second.publicKey)
        keychain.remove("frame-identity")
    }
}
