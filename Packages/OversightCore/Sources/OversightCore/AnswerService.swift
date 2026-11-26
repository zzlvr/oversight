import Foundation

/// Sends one frame and prompt to the selected provider and returns the answer text.
/// Only one request runs at a time; a second call while one is in flight throws `.busy`.
public final class AnswerService: @unchecked Sendable {
    private let provider: VisionProvider
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight = false

    public init(provider: VisionProvider, session: URLSession = makePrivateSession()) {
        self.provider = provider
        self.session = session
    }

    public func ask(prompt: String, frame: Data?, apiKey: String?, model: String) async throws -> String {
        guard begin() else { throw AssistError.busy }
        defer { end() }

        guard let frame, !frame.isEmpty else { throw AssistError.noFrame }
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AssistError.missingKey
        }
        let request = try provider.makeRequest(prompt: prompt, jpeg: frame, apiKey: apiKey, model: model)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AssistError.timeout
        } catch let error as URLError {
            throw AssistError.http(status: 0, message: error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try provider.parseAnswer(data: data, status: status)
    }

    private func begin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    private func end() {
        lock.lock()
        inFlight = false
        lock.unlock()
    }
}
