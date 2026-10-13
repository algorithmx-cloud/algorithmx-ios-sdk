import XCTest
import WebKit
@testable import AlgorithmXSDK

final class InAppViewTests: XCTestCase {
    func testRequestCarriesRequiredHeadersAndEscapedQueryParameters() throws {
        NetworkClient.shared.partnerId = "test-partner"
        let sdk = AlgorithmX()
        let request = try XCTUnwrap(sdk.makeInAppViewsRequest(
            language: "ar-SA", customerId: "customer & one", anonymousId: "visitor-123"
        ))
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/v1/inAppViews")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Partner-Id"), "test-partner")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Anonymous-Id"), "visitor-123")
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first { $0.name == "language" }?.value, "ar-SA")
        XCTAssertEqual(items.first { $0.name == "customerId" }?.value, "customer & one")
    }

    func testResponseMapsDisplayRulesAndKeepsUUIDs() throws {
        var response = fixture()
        response["priority"] = 7
        response["frequency"] = 3
        response["configs"] = ["intervalMinutes": 20, "showAgainAfterDays": 2, "expiresAt": 1900000000000] as [String: Any]
        let view = try XCTUnwrap(InAppView(response))
        XCTAssertEqual(view.campaignId, "22222222-2222-4222-8222-222222222222")
        XCTAssertEqual(view.rule.priority, 7)
        XCTAssertEqual(view.rule.maxShowTime, 3)
        XCTAssertEqual(view.rule.intervalMinutes, 20)
        XCTAssertEqual(view.rule.showAgainAfterDays, 2)
        XCTAssertEqual(view.rule.expiresAt, 1900000000000)
        XCTAssertEqual(view.variation(for: "customer")?.id, "44444444-4444-4444-8444-444444444444")
    }

    func testWeightedAllocationIsStableAndNeverSelectsZeroAllocation() throws {
        var response = fixture()
        var a = (response["variations"] as! [[String: Any]])[0]
        a["allocation"] = 35
        var b = a
        b["id"] = "variation-b"
        b["allocation"] = 65
        var zero = a
        zero["id"] = "variation-zero"
        zero["allocation"] = 0
        response["variations"] = [a, b, zero]
        let view = try XCTUnwrap(InAppView(response))
        var selected = Set<String>()
        for i in 0..<1000 {
            let visitor = "visitor-\(i)"
            let variation = try XCTUnwrap(view.variation(for: visitor))
            XCTAssertEqual(variation.id, view.variation(for: visitor)?.id)
            XCTAssertNotEqual(variation.id, "variation-zero")
            selected.insert(variation.id)
        }
        XCTAssertEqual(selected.count, 2)
        response["variations"] = [zero]
        XCTAssertNil(InAppView(response)?.variation(for: "visitor"))
    }

    func testFractionalAllocationMatchesAndroid() throws {
        let template: [String: Any] = ["html": "<p>Hi</p>"]
        let view = try XCTUnwrap(InAppView(["id": "view-uuid", "campaignId": "campaign-uuid", "language": "en", "frequency": 1,
            "configs": ["delaySeconds": 2.5], "variations": [
                ["id": "a", "allocation": 35.5, "template": template],
                ["id": "b", "allocation": 64.5, "template": template],
                ["id": "z", "allocation": 0, "template": template]]]))
        XCTAssertEqual(view.delaySeconds, 2.5)
        XCTAssertEqual(view.variation(for: "customer_123")?.id, "a")
    }

    func testMalformedCampaignsAndOverallocatedVariationsAreRejected() {
        XCTAssertNil(InAppView([:]))
        var response = fixture()
        response["frequency"] = 0
        XCTAssertNil(InAppView(response))
        response = fixture()
        var variation = (response["variations"] as! [[String: Any]])[0]
        variation["id"] = "another-variation"
        response["variations"] = [variation, variation]
        XCTAssertNil(InAppView(response))
    }

    func testUUIDsArePreservedInInteractionRequest() {
        let body = AlgorithmX.shared.makeCampaignInteractionBody(
            campaignId: "campaign-uuid", variationId: "variation-uuid",
            interactionType: "impression", userId: "visitor"
        )
        XCTAssertEqual(body["campaignId"] as? String, "campaign-uuid")
        XCTAssertEqual(body["variationId"] as? String, "variation-uuid")
    }

    func testFrequencyExpiryAndOtherVariationRulesUsePersistentHistory() {
        let queue = WebViewQueueManager()
        let campaign = UUID().uuidString
        let user = UUID().uuidString
        let rule = WebViewDisplayRule(maxShowTime: 1)
        XCTAssertTrue(queue.canDisplayWebView(campaignId: campaign, variationId: "a", userId: user, rule: rule))
        queue.recordWebViewDisplay(campaignId: campaign, variationId: "a", userId: user)
        XCTAssertFalse(queue.canDisplayWebView(campaignId: campaign, variationId: "a", userId: user, rule: rule))
        XCTAssertFalse(queue.canDisplayWebView(campaignId: campaign, variationId: "b", userId: user, rule: rule))
        XCTAssertTrue(queue.canDisplayWebView(campaignId: campaign, variationId: "a", userId: "other", rule: rule))
        let expired = WebViewDisplayRule(expiresAt: 1)
        XCTAssertFalse(queue.canDisplayWebView(campaignId: UUID().uuidString, variationId: "a", userId: user, rule: expired))
    }

    @MainActor
    func testEnglishTranslationsCSSAndJavaScriptRenderInWebView() throws {
        try assertRendered(language: "en", title: "Info", placeholder: "Enter data", direction: "ltr")
    }

    @MainActor
    func testArabicTranslationsAndRTLRenderInWebView() throws {
        try assertRendered(language: "ar", title: "معلومات", placeholder: "أدخل البيانات", direction: "rtl")
    }

    @MainActor
    func testUnsupportedLanguageFallsBackToEnglish() throws {
        try assertRendered(language: "fr", title: "Info", placeholder: "Enter data", direction: "ltr")
    }

    func testGetArrayRejectsHTTPFailureAndNonArrayResponses() {
        assertNetwork(status: 500, json: "[]", expectedCount: nil)
        assertNetwork(status: 200, json: "{}", expectedCount: nil)
        assertNetwork(status: 200, json: "not json", expectedCount: nil)
        assertNetwork(status: 200, json: "[]", expectedCount: 0)
        assertNetwork(status: 200, json: "[{\"id\":\"view\"}]", expectedCount: 1)
    }

    private func assertNetwork(status: Int, json: String, expectedCount: Int?) {
        let received = expectation(description: "GET completed")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InAppURLProtocol.self]
        let previous = NetworkClient.shared.session
        NetworkClient.shared.session = URLSession(configuration: configuration)
        InAppURLProtocol.status = status
        InAppURLProtocol.json = json
        defer {
            NetworkClient.shared.session.invalidateAndCancel()
            NetworkClient.shared.session = previous
        }
        NetworkClient.shared.getJsonArray(request: URLRequest(url: URL(string: "https://sdk-test.invalid/views")!)) { result in
            switch result {
            case .success(let array): XCTAssertEqual(array.count, expectedCount)
            case .failure: XCTAssertNil(expectedCount)
            }
            received.fulfill()
        }
        wait(for: [received], timeout: 5)
    }

    @MainActor
    private func assertRendered(language: String, title: String, placeholder: String, direction: String) throws {
        let view = try XCTUnwrap(InAppView(fixture()))
        let template = view.variations[0].template
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: template.translationScript(language: language), injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        let window = UIWindow(frame: webView.frame)
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true }
        let loaded = expectation(description: "HTML rendered")
        let delegate = InAppNavigationDelegate {
            webView.evaluateJavaScript("""
                ({title:document.getElementById('title').textContent,
                  placeholder:document.getElementById('field').placeholder,
                  direction:document.documentElement.dir,
                  fallback:document.getElementById('fallback').textContent,
                  safe:document.getElementById('safe').textContent,
                  children:document.getElementById('safe').children.length,
                  color:getComputedStyle(document.getElementById('title')).color,
                  ran:window.templateRan})
                """) { result, error in
                XCTAssertNil(error)
                let result = result as? [String: Any]
                XCTAssertEqual(result?["title"] as? String, title)
                XCTAssertEqual(result?["placeholder"] as? String, placeholder)
                XCTAssertEqual(result?["direction"] as? String, direction)
                XCTAssertEqual(result?["fallback"] as? String, "Original")
                XCTAssertEqual(result?["safe"] as? String, "<b>Plain text</b>")
                XCTAssertEqual(result?["children"] as? Int, 0)
                XCTAssertEqual(result?["color"] as? String, "rgb(1, 2, 3)")
                XCTAssertEqual(result?["ran"] as? Bool, true)
                loaded.fulfill()
            }
        }
        webView.navigationDelegate = delegate
        webView.loadHTMLString(template.document, baseURL: nil)
        wait(for: [loaded], timeout: 30)
        withExtendedLifetime(delegate) {}
    }

    private func fixture() -> [String: Any] {
        let english = [
            "t_txt_1": ["type": "text", "value": "Info"],
            "t_ph_1": ["type": "placeholder", "value": "Enter data"],
            "safe": ["type": "text", "value": "<b>Plain text</b>"],
        ]
        let arabic = [
            "t_txt_1": ["type": "text", "value": "معلومات"],
            "t_ph_1": ["type": "placeholder", "value": "أدخل البيانات"],
            "safe": ["type": "text", "value": "<b>Plain text</b>"],
        ]
        return [
            "id": "11111111-1111-4111-8111-111111111111",
            "campaignId": "22222222-2222-4222-8222-222222222222",
            "language": "en", "priority": 1, "frequency": 1,
            "configs": ["intervalMinutes": 0, "showAgainAfterDays": 0, "expiresAt": 0],
            "variations": [[
                "id": "44444444-4444-4444-8444-444444444444", "allocation": 100,
                "parameters": ["coupon": "SAVE20"],
                "template": [
                    "html": "<h2 id='title' data-t-key='t_txt_1'>Fallback</h2><input id='field' data-t-key='t_ph_1' placeholder='Fallback'><p id='fallback' data-t-key='missing'>Original</p><p id='safe' data-t-key='safe'></p>",
                    "css": "h2 { color: rgb(1, 2, 3); }", "js": "window.templateRan = true;",
                    "builderState": ["translations": ["en": english, "ar": arabic]],
                ] as [String: Any],
            ] as [String: Any]],
        ]
    }
}

private final class InAppNavigationDelegate: NSObject, WKNavigationDelegate {
    private let loaded: () -> Void
    init(loaded: @escaping () -> Void) { self.loaded = loaded }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded() }
}

private final class InAppURLProtocol: URLProtocol {
    static var status = 200
    static var json = "[]"
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
