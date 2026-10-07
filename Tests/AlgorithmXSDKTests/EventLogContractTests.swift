import XCTest
@testable import AlgorithmXSDK

final class EventLogContractTests: XCTestCase {
    func testTrackEventSendsBackendContractAndPreservesCustomData() {
        assertEvent(properties: ["Product_ID": "SKU-123", "nested": [1, true]])
    }

    func testTrackEventWithoutPropertiesSendsEmptyData() {
        assertEvent(properties: nil)
    }

    private func assertEvent(properties: [String: Any]?) {
        let received = expectation(description: "Event request")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EventLogURLProtocol.self]
        let previousSession = NetworkClient.shared.session
        NetworkClient.shared.session = URLSession(configuration: configuration)
        defer {
            NetworkClient.shared.session.invalidateAndCancel()
            NetworkClient.shared.session = previousSession
            EventLogURLProtocol.onRequest = nil
        }
        EventLogURLProtocol.onRequest = { request, body in
            XCTAssertEqual(request.url?.path, "/api/v1/Event/Log")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-partner-id"), "test-partner")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Anonymous-Id"), "customer_123")
            let events = try! JSONSerialization.jsonObject(with: body) as! [[String: Any]]
            XCTAssertEqual(events.count, 1)
            let event = events[0]
            XCTAssertEqual(event["eventType"] as? String, "Purchase_COMPLETED/Custom")
            XCTAssertNil(event["fingerprintDevice"])
            let data = event["data"] as! [String: Any]
            if properties == nil {
                XCTAssertTrue(data.isEmpty)
            } else {
                XCTAssertEqual(data["Product_ID"] as? String, "SKU-123")
                XCTAssertEqual((data["nested"] as? [Any])?.count, 2)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            XCTAssertNotNil(formatter.date(from: event["timestamp"] as! String))
            received.fulfill()
        }
        NetworkClient.shared.partnerId = "test-partner"
        AlgorithmX.shared.setDeviceFingerprint("customer_123")
        let request = AlgorithmX.shared.makeEventLogRequest("Purchase_COMPLETED/Custom", properties: properties)
        EventDispatcher.shared.send(
            endpoint: "https://sdk-test.invalid/api/v1/Event/Log", method: "POST",
            payload: request.payload, headers: request.headers
        )
        wait(for: [received], timeout: 5)
    }
}

private final class EventLogURLProtocol: URLProtocol {
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
        let response = HTTPURLResponse(url: request.url!, statusCode: 202,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"eventsQueued\":1}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
