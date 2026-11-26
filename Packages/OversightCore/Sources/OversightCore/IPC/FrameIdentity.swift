import CryptoKit
import Foundation

/// A signing key. The app and the broadcast extension each have one, remember the other's
/// public key the first time they meet, and accept nobody else afterwards.
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

    /// 64 bytes of public key followed by a 64 byte signature of `message`.
    func proof(of message: Data) -> Data? {
        guard let signature = try? key.signature(for: message) else { return nil }
        return publicKey + signature.rawRepresentation
    }
}

/// Where one side keeps the public key of the other.
public struct PinStore {
    let load: () -> Data?
    let save: (Data) -> Void

    public init(load: @escaping () -> Data?, save: @escaping (Data) -> Void) {
        self.load = load
        self.save = save
    }

    /// True if `proof` signs `message` with the trusted key (trusting the first valid one seen).
    func accepts(proof: Data, of message: Data) -> Bool {
        guard proof.count == 128 else { return false }
        let publicKey = Data(proof.prefix(64))
        if let pinned = load(), pinned != publicKey { return false }
        guard let key = try? P256.Signing.PublicKey(rawRepresentation: publicKey),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: Data(proof.dropFirst(64))),
              key.isValidSignature(signature, for: message)
        else { return false }
        if load() == nil { save(publicKey) }
        return true
    }
}
