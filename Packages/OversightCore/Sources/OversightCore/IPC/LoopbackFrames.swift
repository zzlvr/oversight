import CryptoKit
import Foundation
import Network

// Frames travel from the broadcast extension to the app over the loopback interface,
// one TCP connection per frame:
//   extension -> app: 32 random bytes (A)
//   app -> extension: app key and signature of A, then 32 random bytes (B)
//   extension -> app: extension key and signature of B and the payload hash, then the payload,
//                     then end of stream (an empty payload means the broadcast ended)

public let framePort: UInt16 = 47615
private let nonceLength = 32
private let proofLength = 128
private let maxFrameBytes = 3_000_000
private let maxConnections = 4

private func randomNonce() -> Data {
    var generator = SystemRandomNumberGenerator()
    return Data((0..<nonceLength).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
}

private func appMessage(_ nonce: Data) -> Data {
    Data("oversight-app".utf8) + nonce
}

private func frameMessage(_ nonce: Data, _ payload: Data) -> Data {
    Data("oversight-frame".utf8) + nonce + Data(SHA256.hash(data: payload))
}

public enum ListenerState: Equatable {
    case ready
    case failed(String)
}

public final class FrameReceiver: @unchecked Sendable {
    private let identity: FrameIdentity
    private let senders: PinStore
    private let deadline: TimeInterval
    private let queue = DispatchQueue(label: "oversight.frames.receive")
    private var listener: NWListener?
    private var open: [ObjectIdentifier: NWConnection] = [:]

    public init(identity: FrameIdentity, senders: PinStore, deadline: TimeInterval = 5) {
        self.identity = identity
        self.senders = senders
        self.deadline = deadline
    }

    public func start(port: UInt16 = framePort,
                      onState: @escaping (ListenerState) -> Void,
                      onFrame: @escaping (Data) -> Void,
                      onEnd: @escaping () -> Void) {
        stop()
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready: onState(.ready)
                case .failed(let error), .waiting(let error): onState(.failed(error.localizedDescription))
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection, onFrame: onFrame, onEnd: onEnd)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            onState(.failed(error.localizedDescription))
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    /// Runs on `queue`. Limits how many connections exist and how long each may take.
    private func accept(_ connection: NWConnection,
                        onFrame: @escaping (Data) -> Void, onEnd: @escaping () -> Void) {
        guard open.count < maxConnections else { return connection.cancel() }
        let id = ObjectIdentifier(connection)
        open[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed: self?.open[id] = nil
            default: break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + deadline) { [weak connection] in connection?.cancel() }
        handshake(connection, onFrame: onFrame, onEnd: onEnd)
    }

    private func handshake(_ connection: NWConnection,
                           onFrame: @escaping (Data) -> Void, onEnd: @escaping () -> Void) {
        connection.receive(minimumIncompleteLength: nonceLength, maximumLength: nonceLength) { [weak self] data, _, _, _ in
            guard let self, let nonce = data, nonce.count == nonceLength,
                  let proof = self.identity.proof(of: appMessage(nonce))
            else { return connection.cancel() }
            let challenge = randomNonce()
            connection.send(content: proof + challenge, completion: .contentProcessed { _ in })
            self.collect(connection, challenge: challenge, collected: Data(), onFrame: onFrame, onEnd: onEnd)
        }
    }

    private func collect(_ connection: NWConnection, challenge: Data, collected: Data,
                         onFrame: @escaping (Data) -> Void, onEnd: @escaping () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }
            var collected = collected
            if let data { collected.append(data) }
            if collected.count > proofLength + maxFrameBytes {
                connection.cancel()
            } else if isComplete {
                let payload = Data(collected.dropFirst(proofLength))
                if self.senders.accepts(proof: Data(collected.prefix(proofLength)),
                                        of: frameMessage(challenge, payload)) {
                    if payload.isEmpty { onEnd() } else { onFrame(payload) }
                }
                connection.cancel()
            } else if error != nil {
                connection.cancel()
            } else {
                self.collect(connection, challenge: challenge, collected: collected, onFrame: onFrame, onEnd: onEnd)
            }
        }
    }
}

/// Sends one payload at a time. A frame offered while another is in flight is dropped;
/// the end-of-broadcast signal (an empty payload) waits its turn instead.
public final class FrameSender: @unchecked Sendable {
    private let port: UInt16
    private let identity: FrameIdentity
    private let pins: PinStore
    private let queue = DispatchQueue(label: "oversight.frames.send")
    private var current: NWConnection?
    private var pendingEnd: ((Bool) -> Void)?

    public init(port: UInt16 = framePort, identity: FrameIdentity, pins: PinStore) {
        self.port = port
        self.identity = identity
        self.pins = pins
    }

    public func send(_ payload: Data, completion: ((Bool) -> Void)? = nil) {
        queue.async {
            guard self.current == nil else {
                if payload.isEmpty {
                    self.pendingEnd = completion ?? { _ in }
                } else {
                    completion?(false)
                }
                return
            }
            let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: self.port)!, using: .tcp)
            self.current = connection

            let finish: (Bool) -> Void = { success in
                guard self.current === connection else { return }
                self.current = nil
                connection.cancel()
                completion?(success)
                if let end = self.pendingEnd {
                    self.pendingEnd = nil
                    self.send(Data(), completion: end)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: self.exchange(connection, payload: payload, finish: finish)
                case .failed, .waiting: finish(false)
                default: break
                }
            }
            connection.start(queue: self.queue)
            self.queue.asyncAfter(deadline: .now() + 3) { finish(false) }
        }
    }

    private func exchange(_ connection: NWConnection, payload: Data, finish: @escaping (Bool) -> Void) {
        let nonce = randomNonce()
        let replyLength = proofLength + nonceLength
        connection.send(content: nonce, completion: .contentProcessed { _ in })
        connection.receive(minimumIncompleteLength: replyLength, maximumLength: replyLength) { data, _, _, _ in
            guard let reply = data, reply.count == replyLength,
                  self.pins.accepts(proof: Data(reply.prefix(proofLength)), of: appMessage(nonce)),
                  let proof = self.identity.proof(of: frameMessage(Data(reply.dropFirst(proofLength)), payload))
            else { return finish(false) }
            connection.send(content: proof + payload, contentContext: .finalMessage,
                            isComplete: true, completion: .contentProcessed { error in finish(error == nil) })
        }
    }
}
