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

    /// Loads the key from the Keychain, creating it on first use. If the Keychain refuses to
    /// save it, the key is kept in `fallback`, so that the extension keeps recognising the app.
    public static func load(from store: SecretStore, fallback: UserDefaults = .standard) -> FrameIdentity {
        let account = "frame-identity"
        if let saved = store.get(account) ?? fallback.string(forKey: account),
           let raw = Data(base64Encoded: saved),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: raw) {
            return FrameIdentity(key: key)
        }
        let identity = FrameIdentity()
        let encoded = identity.key.rawRepresentation.base64EncodedString()
        do {
            try store.set(encoded, for: account)
        } catch {
            fallback.set(encoded, forKey: account)
        }
        return identity
    }

    /// For the broadcast extension: kept in its own sandboxed preferences, which are removed
    /// together with the app, like the key the app remembers for it.
    public static func load(from defaults: UserDefaults) -> FrameIdentity {
        let name = "frameIdentity"
        if let raw = defaults.data(forKey: name),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: raw) {
            return FrameIdentity(key: key)
        }
        let identity = FrameIdentity()
        defaults.set(identity.key.rawRepresentation, forKey: name)
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
