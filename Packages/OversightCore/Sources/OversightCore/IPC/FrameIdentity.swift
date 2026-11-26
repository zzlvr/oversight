import CryptoKit
import Foundation

/// The app's signing key. The broadcast extension remembers the public half the first time
/// it connects and afterwards sends frames only to a listener that can sign with it.
public struct FrameIdentity {
    let key: P256.Signing.PrivateKey

    public init() {
        key = P256.Signing.PrivateKey()
    }

    init(key: P256.Signing.PrivateKey) {
        self.key = key
    }

    public var publicKey: Data { key.publicKey.rawRepresentation }

    /// Loads the key from the Keychain, creating and saving it on first use.
    public static func load(from keychain: KeychainStore) -> FrameIdentity {
        let account = "frame-identity"
        if let saved = keychain.get(account),
           let raw = Data(base64Encoded: saved),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: raw) {
            return FrameIdentity(key: key)
        }
        let identity = FrameIdentity()
        try? keychain.set(identity.key.rawRepresentation.base64EncodedString(), for: account)
        return identity
    }

    func reply(to nonce: Data) -> Data? {
        guard let signature = try? key.signature(for: nonce) else { return nil }
        return publicKey + signature.rawRepresentation
    }
}

/// Where the extension keeps the public key it trusts.
public struct PinStore {
    let load: () -> Data?
    let save: (Data) -> Void

    public init(load: @escaping () -> Data?, save: @escaping (Data) -> Void) {
        self.load = load
        self.save = save
    }

    /// True if `reply` proves the listener holds the trusted key (trusting the first one seen).
    func accepts(reply: Data, nonce: Data) -> Bool {
        let publicKey = Data(reply.prefix(64))
        if let pinned = load(), pinned != publicKey { return false }
        guard let key = try? P256.Signing.PublicKey(rawRepresentation: publicKey),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: Data(reply.dropFirst(64))),
              key.isValidSignature(signature, for: nonce)
        else { return false }
        if load() == nil { save(publicKey) }
        return true
    }
}
