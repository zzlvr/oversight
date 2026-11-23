import XCTest
@testable import OversightCore

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var delay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay) {
            do {
                let (status, data) = try Self.handler!(self.request)
                let response = HTTPURLResponse(url: self.request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: nil)!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
}

final class AnswerServiceTests: XCTestCase {
    private let frame = Data([0xFF, 0xD8, 0xFF, 0xD9])

    private func makeService() -> AnswerService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return AnswerService(provider: provider(for: .claude), session: URLSession(configuration: config))
    }

    override func setUp() {
        StubURLProtocol.delay = 0
        StubURLProtocol.handler = { _ in (200, Data(#"{"content":[{"type":"text","text":"Tap Buy."}]}"#.utf8)) }
    }

    func testReturnsAnswerText() async throws {
        let answer = try await makeService().ask(prompt: "p", frame: frame, apiKey: "k", model: "m")
        XCTAssertEqual(answer, "Tap Buy.")
    }

    func testAskWithoutFrameThrowsNoFrame() async {
        do {
            _ = try await makeService().ask(prompt: "p", frame: nil, apiKey: "k", model: "m")
            XCTFail("expected error")
        } catch { XCTAssertEqual(error as? AssistError, .noFrame) }
    }

    func testAskWithoutKeyThrowsMissingKey() async {
        do {
            _ = try await makeService().ask(prompt: "p", frame: frame, apiKey: nil, model: "m")
            XCTFail("expected error")
        } catch { XCTAssertEqual(error as? AssistError, .missingKey) }
    }

    func testInvalidKeyResponseBecomesReadableHttpError() async {
        StubURLProtocol.handler = { _ in
            (401, Data(#"{"error":{"message":"invalid x-api-key"}}"#.utf8))
        }
        do {
            _ = try await makeService().ask(prompt: "p", frame: frame, apiKey: "bad", model: "m")
            XCTFail("expected error")
        } catch { XCTAssertEqual(error as? AssistError, .http(status: 401, message: "invalid x-api-key")) }
    }

    func testTimeoutMapsToTimeout() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        do {
            _ = try await makeService().ask(prompt: "p", frame: frame, apiKey: "k", model: "m")
            XCTFail("expected error")
        } catch { XCTAssertEqual(error as? AssistError, .timeout) }
    }

    func testOfflineMapsToHttpErrorWithStatusZero() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await makeService().ask(prompt: "p", frame: frame, apiKey: "k", model: "m")
            XCTFail("expected error")
        } catch {
            guard case .http(let status, _) = error as? AssistError else { return XCTFail("wrong error \(error)") }
            XCTAssertEqual(status, 0)
        }
    }

    func testSecondConcurrentAskThrowsBusy() async throws {
        StubURLProtocol.delay = 0.5
        let service = makeService()
        let first = Task { try await service.ask(prompt: "p", frame: frame, apiKey: "k", model: "m") }
        try await Task.sleep(nanoseconds: 150_000_000)
        do {
            _ = try await service.ask(prompt: "p", frame: frame, apiKey: "k", model: "m")
            XCTFail("expected busy")
        } catch { XCTAssertEqual(error as? AssistError, .busy) }
        let answer = try await first.value
        XCTAssertEqual(answer, "Tap Buy.")
    }

    func testServiceIsReusableAfterAnAnswer() async throws {
        let service = makeService()
        _ = try await service.ask(prompt: "p", frame: frame, apiKey: "k", model: "m")
        let second = try await service.ask(prompt: "p", frame: frame, apiKey: "k", model: "m")
        XCTAssertEqual(second, "Tap Buy.")
    }
}
