import XCTest
@testable import AlgorithmXSDK

final class IdentityContractTests: XCTestCase {
    private let keys = ["algorithmx.anonymousId", "algorithmx.deviceId", AlgorithmX.identifiedUserIdKey]
    private var previous: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in keys {
            previous[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
            if let value = previous[key] { UserDefaults.standard.set(value, forKey: key) }
        }
        super.tearDown()
    }

    func testUuidSurvivesLoginAndRestartButRotatesOnLogoutAndAccountChange() {
        let sdk = AlgorithmX()
        let anonymous = sdk.getAnonymousId()
        XCTAssertNotNil(UUID(uuidString: anonymous))
        sdk.identifyUser(userId: "customer_a", attributes: ["email": "a@example.com"])
        XCTAssertEqual(sdk.getAnonymousId(), anonymous)
        XCTAssertEqual(AlgorithmX().getAnonymousId(), anonymous)
        sdk.identifyUser(userId: "customer_b")
        let switched = sdk.getAnonymousId()
        XCTAssertNotEqual(switched, anonymous)
        sdk.resetIdentity()
        XCTAssertNotEqual(sdk.getAnonymousId(), switched)
        XCTAssertNil(UserDefaults.standard.object(forKey: AlgorithmX.identifiedUserIdKey))
        XCTAssertEqual(AlgorithmX().getAnonymousId(), sdk.getAnonymousId())
    }

    func testRejectsUnsupportedTraitsAndIncorrectConsentTypes() throws {
        XCTAssertThrowsError(try IdentityPayload.profile(["plan": "premium"]))
        XCTAssertThrowsError(try IdentityPayload.profile(["emailOptIn": "true"]))
        XCTAssertThrowsError(try IdentityPayload.profile(["emailOptIn": 1]))
        XCTAssertThrowsError(try IdentityPayload.identifiers(userId: " ", attributes: nil))
        let profile = try IdentityPayload.profile(["firstName": "Amina", "emailOptIn": false])
        XCTAssertEqual(profile["emailOptIn"] as? Bool, false)
    }

    func testPostsBootstrapIdentityProfileAndEventWithTheSameAnonymousUuid() {
        let done = expectation(description: "event after profile")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [IdentityURLProtocol.self]
        let oldSession = NetworkClient.shared.session
        NetworkClient.shared.session = URLSession(configuration: configuration)
        var paths: [String] = []
        let sdk = AlgorithmX()
        let anonymous = sdk.getAnonymousId()
        IdentityURLProtocol.onRequest = { request, body in
            let path = request.url!.path
            if path == "/api/v1/inAppViews" { return }
            paths.append(path)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-partner-id"), "identity-test")
            let json = try! JSONSerialization.jsonObject(with: body)
            switch path {
            case "/api/v1/Identity/Bootstrap":
                let payload = json as! [String: Any]
                XCTAssertEqual(payload["anonymousId"] as? String, anonymous)
                XCTAssertNotNil(UUID(uuidString: payload["deviceId"] as! String))
                XCTAssertNotNil(payload["userAgent"])
            case "/api/v1/Identity":
                let payload = json as! [String: Any]
                XCTAssertEqual(payload["anonymousId"] as? String, anonymous)
                let ids = payload["trustedIdentifiers"] as! [String: String]
                XCTAssertEqual(ids["ExternalId"], "customer_123")
                XCTAssertEqual(ids["Email"], "user@example.com")
                XCTAssertNil(payload["attributes"])
            case "/api/v1/Customer/Ingest":
                let payload = json as! [String: Any]
                XCTAssertEqual(payload["firstName"] as? String, "Amina")
                XCTAssertEqual(payload["pushOptIn"] as? Bool, true)
                XCTAssertNil(payload["email"])
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Anonymous-Id"), anonymous)
                XCTAssertNotNil(UUID(uuidString: request.value(forHTTPHeaderField: "X-Device-Id")!))
            case "/api/v1/Event/Log":
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Anonymous-Id"), anonymous)
                XCTAssertLessThan(paths.firstIndex(of: "/api/v1/Identity/Bootstrap")!, paths.firstIndex(of: "/api/v1/Identity")!)
                XCTAssertLessThan(paths.firstIndex(of: "/api/v1/Identity")!, paths.firstIndex(of: "/api/v1/Customer/Ingest")!)
                done.fulfill()
            default: XCTFail("Unexpected request: \(path)")
            }
        }
        sdk.initializeIdentity(apiBaseUrl: "https://identity-test.invalid", partnerId: "identity-test")
        sdk.setInAppLanguage("ar-SA")
        sdk.identifyUser(userId: "customer_123", attributes: ["email": "user@example.com", "firstName": "Amina", "pushOptIn": true])
        let inAppRequest = sdk.makeCurrentInAppViewsRequest()!
        let query = URLComponents(url: inAppRequest.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "customerId" }?.value, "customer_123")
        XCTAssertEqual(query.first { $0.name == "language" }?.value, "ar-SA")
        XCTAssertEqual(inAppRequest.value(forHTTPHeaderField: "X-Anonymous-Id"), anonymous)
        XCTAssertNotNil(UUID(uuidString: inAppRequest.value(forHTTPHeaderField: "X-Device-Id")!))
        sdk.trackEvent("productView", properties: ["productId": "SKU-1"])
        wait(for: [done], timeout: 10)
        XCTAssertEqual(sdk.getAnonymousId(), anonymous)
        NetworkClient.shared.session = oldSession
        IdentityURLProtocol.onRequest = nil
    }
}

private final class IdentityURLProtocol: URLProtocol {
    static var onRequest: ((URLRequest, Data) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
        }
        Self.onRequest?(request, body)
        let response = HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // IdentityController returns an empty 202 response; the SDK must continue dispatching.
        let responseBody = request.url?.path == "/api/v1/Customer/Ingest" ? Data("{}".utf8) : Data()
        client?.urlProtocol(self, didLoad: responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
