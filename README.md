# AlgorithmX iOS SDK

> **Naming recommendation:** Use camelCase for custom event names and payload keys, for example `purchaseCompleted` and `productId`. The SDK preserves custom names, keys, values, and title text exactly as supplied; it does not enforce or convert their casing.

Connect your iOS app to [AlgorithmX](https://algorithmx.cloud), the campaign management and customer data platform. The SDK sends customer identity and events, handles AlgorithmX push notifications, routes campaign actions to your app, and shows in-app campaigns.

- iOS 15 or later, Xcode 15 or later
- No third-party dependencies
- Includes an Apple privacy manifest

## Installation

### Swift Package Manager

In Xcode, choose **File → Add Package Dependencies**, enter the repository URL, and add the **AlgorithmXSDK** library to your app target:

```
https://github.com/algorithmx-cloud/algorithmx-ios-sdk
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/algorithmx-cloud/algorithmx-ios-sdk", from: "1.0.2")
```

### CocoaPods

Install the pod from its Git tag:

```ruby
pod 'AlgorithmXSDK', :git => 'https://github.com/algorithmx-cloud/algorithmx-ios-sdk.git', :tag => '1.0.2'
```

## Quick start

```swift
import AlgorithmXSDK

// In application(_:didFinishLaunchingWithOptions:)
AlgorithmX.shared.initialize(apiBaseUrl: "https://api.example.com", partnerId: "your-partner-id")

AlgorithmX.shared.trackEvent("purchaseCompleted", properties: [
    "productId": "sku123",
    "orderTotal": 49.99
])
```

AlgorithmX gives you the API base URL and your partner ID. The SDK sends the partner ID in the `x-partner-id` header of every SDK API request.

SDK-defined fields and built-in events use camelCase. Campaign interactions send `fingerprintDevice`, `campaignId`, `variationId`, `interactionType`, and `payload` to `/api/v1/tracks/algoViewInteract`. Push payloads use keys such as `engageAction`, `algoCampaignId`, `engageVariationId`, `actionType`, `actionButtons`, and `actionText`, with built-in actions such as `algoTriggerWebview`, `algoShowNotification`, `openWebPage`, `openWebview`, `openScreen`, and `customAction`. The WebView bridge accepts `campaignClose`, `campaignClick`, `campaignSubmit`, `campaignCouponCopy`, and `copyCoupon`. Legacy push keys, built-in action values, and bridge event names remain accepted; explicit camelCase keys take precedence.

## SDK HTTP endpoints

API URLs are the initialized `apiBaseUrl` plus the paths below. Every SDK API request includes the `x-partner-id` header containing the initialized partner ID.

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/v1/identify` | Identify the customer and send optional attributes. |
| `POST` | `/api/v1/tracks/{eventName}` | Send a custom event with its original name and payload. |
| `POST` | `/api/v1/tracks/algoViewInteract` | Report campaign and push interactions. |
| `PUT` | `/api/v1/inAppPushEvents/device/status` | Update notification delivery or open status. |
| `POST` | `/api/v1/notificationTokens` | Register a push token for the current customer. |

`{eventName}` is the custom name supplied to `trackEvent`; the SDK keeps it unchanged. Campaign HTML and notification images are downloaded with `GET` from their supplied URLs, so those downloads have no fixed SDK path. Campaign HTML may also load its own resources. A caller-supplied campaign interaction `endpoint` overrides the default interaction path.

The integration guide covers the full setup: customer identity, events, push notifications, deep links, custom actions, and the notification service extension.

**[iOS integration guide →](https://algorithmx.cloud/en/docs/integrations/ios)**

## License

MIT. See [LICENSE](LICENSE).
