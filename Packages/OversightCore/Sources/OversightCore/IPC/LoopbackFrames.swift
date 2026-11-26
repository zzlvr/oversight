import Foundation
import Network

// Frames travel from the broadcast extension to the app over the loopback interface,
// one TCP connection per frame:
//   extension -> app: 32 random bytes
//   app -> extension: 64 byte public key + 64 byte signature of those bytes
//   extension -> app: the JPEG, then end of stream (an empty payload means the broadcast ended)

public let framePort: UInt16 = 47615
private let nonceLength = 32
private let replyLength = 128
private let maxFrameBytes = 5_000_000

public enum ListenerState: Equatable {
    case ready
    case failed(String)
}

public final class FrameReceiver: @unchecked Sendable {
    private let identity: FrameIdentity
    private let queue = DispatchQueue(label: "oversight.frames.receive")
    private var listener: NWListener?

    public init(identity: FrameIdentity) {
        self.identity = identity
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
                case .failed(let error): onState(.failed(error.localizedDescription))
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                connection.start(queue: self.queue)
                self.handshake(connection, onFrame: onFrame, onEnd: onEnd)
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

    private func handshake(_ connection: NWConnection,
                           onFrame: @escaping (Data) -> Void, onEnd: @escaping () -> Void) {
        connection.receive(minimumIncompleteLength: nonceLength, maximumLength: nonceLength) { [weak self] data, _, _, _ in
            guard let self, let nonce = data, nonce.count == nonceLength,
                  let reply = self.identity.reply(to: nonce)
            else { return connection.cancel() }
            connection.send(content: reply, completion: .contentProcessed { _ in })
            self.collect(connection, collected: Data(), onFrame: onFrame, onEnd: onEnd)
        }
    }

    private func collect(_ connection: NWConnection, collected: Data,
                         onFrame: @escaping (Data) -> Void, onEnd: @escaping () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            var collected = collected
            if let data { collected.append(data) }
            if collected.count > maxFrameBytes {
                connection.cancel()
            } else if isComplete {
                if collected.isEmpty { onEnd() } else { onFrame(collected) }
                connection.cancel()
            } else if error != nil {
                connection.cancel()
            } else {
                self?.collect(connection, collected: collected, onFrame: onFrame, onEnd: onEnd)
            }
        }
    }
}

/// Sends one payload at a time; a payload offered while another is in flight is dropped.
public final class FrameSender: @unchecked Sendable {
    private let port: UInt16
    private let pins: PinStore
    private let queue = DispatchQueue(label: "oversight.frames.send")
    private var current: NWConnection?

    public init(port: UInt16 = framePort, pins: PinStore) {
        self.port = port
        self.pins = pins
    }

    public func send(_ payload: Data, completion: ((Bool) -> Void)? = nil) {
        queue.async {
            guard self.current == nil else {
                completion?(false)
                return
            }
            let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: self.port)!, using: .tcp)
            self.current = connection

            let finish: (Bool) -> Void = { success in
                guard self.current === connection else { return }
                self.current = nil
                connection.cancel()
                completion?(success)
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
        var generator = SystemRandomNumberGenerator()
        let nonce = Data((0..<nonceLength).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
        connection.send(content: nonce, completion: .contentProcessed { _ in })
        connection.receive(minimumIncompleteLength: replyLength, maximumLength: replyLength) { data, _, _, _ in
            guard let reply = data, reply.count == replyLength, self.pins.accepts(reply: reply, nonce: nonce) else {
                return finish(false)
            }
            connection.send(content: payload.isEmpty ? nil : payload, contentContext: .finalMessage,
                            isComplete: true, completion: .contentProcessed { error in finish(error == nil) })
        }
    }
}
