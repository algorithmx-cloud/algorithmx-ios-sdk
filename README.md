# AlgorithmX iOS SDK

## API-based in-app views

**Production backend support is pending:** the .NET in-app delivery route must be implemented as described in [AlgorithmX issue #207](https://github.com/algorithmx-cloud/AlgorithmX/issues/207). Current device tests use `in-app-test-backend`; no .NET implementation is included in this SDK update.

In-app campaigns use the API in SDK 1.1.0. Initialise the SDK and identify a signed-in customer; no campaign-fetch code, silent push, push token, or notification permission is needed for this flow.

1. The SDK bootstraps its anonymous profile and device automatically.
2. On startup or returning to the foreground, it calls `GET /api/v1/inAppViews?language=...&customerId=...`.
3. The backend checks the customer's segment, campaign publication/schedule and language, and returns eligible inline HTML, CSS, JavaScript, translations and variation parameters.
4. The SDK selects a stable variation, applies priority, frequency, expiry and app-enter delay, and displays at most one campaign per visit. The template supplies its close button; Android also supports Back.

The SDK supplies `X-Partner-Id`, its persistent UUID in `X-Anonymous-Id`, and the installation UUID in `X-Device-Id`. Before login, `customerId` is the anonymous UUID. After `identify` / `identifyUser`, it is your application's account ID, stored by AlgorithmX as `ExternalId`. The backend resolves the internal profile ID; your app does not pass an AlgorithmX profile UUID. Identification, logout and account changes invalidate old campaign requests and content. Signed-in variation selection and local display history use the account ID.

Language defaults to the device/app language. Override it only when your app has its own language selector:

```swift
AlgorithmX.shared.setInAppLanguage("ar")
```

An empty language override restores the automatic default. Arabic, Hebrew, Persian and Urdu translations use RTL layout; text and placeholder translations are applied from the template's `builderState.translations`.

**First check:** publish an active campaign that matches your test customer's segment and language, open the app, and confirm the GET request and impression. Leave the app and return to check another visit. Impressions, clicks, submits, copies and closes are logged through `POST /api/v1/Event/Log` as `inAppViewInteraction`; campaign and variation UUIDs remain strings.

The automatic mobile flow supports app-enter campaigns and an optional time delay. Browser URL/scroll/exit/inactivity rules and custom triggers are excluded by the backend from this automatic feed. Display history is stored on the installation; this is not a global cross-device frequency counter.

GET requests follow queued identity/profile POSTs. When identity is still processing (`409`), the SDK retries up to three times, and it retries again when connectivity returns or the app re-enters the foreground. Normal event/profile requests remain fire-and-forget. The old silent-push `algoTriggerWebview` is ignored. Visible push notifications retain their separate integration.


> **SDK 1.1.0:** these APIs use SDK-generated anonymous/device IDs and API-based in-app delivery. Existing 1.0.x integrations should follow the updated identity and profile instructions below.

## Customer identity and profile data

The SDK generates and stores an anonymous UUID and a separate installation device UUID during startup. You do not generate either ID or call the bootstrap endpoint yourself. The anonymous UUID stays the same across app restarts and login; events continue to use it in `X-Anonymous-Id`.

Use the stable account ID from your application's backend when the customer signs in. The SDK sends it as `ExternalId`, allowing AlgorithmX to resolve the same customer across devices. AlgorithmX manages its own internal profile ID.

Call the identity function after login and when starting with a signed-in customer. Email and phone become trusted identifiers; supported profile fields are sent separately to `/Customer/Ingest`.

```swift
AlgorithmX.shared.identifyUser(userId: "customer_123", attributes: [
    "email": "amina@example.com",
    "firstName": "Amina", "lastName": "Hassan",
    "emailOptIn": true, "smsOptIn": false, "pushOptIn": true,
    "gdprAccepted": true, "whatsAppOptIn": false
])
```

Supported identifier fields are `email`, `phone`, and `userName`; your application's `userId` becomes `ExternalId`. Supported profile fields are `firstName`, `lastName`, `gender`, `dateOfBirth`, `registeredAt`, `emailOptIn`, `smsOptIn`, `pushOptIn`, `gdprAccepted`, and `whatsAppOptIn`. Send dates as ISO 8601 text and consent fields as booleans.

**Send a complete profile.** `/Customer/Ingest` replaces these traits: omitted text/date fields are cleared and omitted consent fields become `false`. Include all current values whenever you send profile fields through `identify` / `identifyUser` or `setUserProfile`. An identify call containing only identifiers does not send a profile update.

Fields such as `plan`, `language`, `country`, and `loyaltyTier` are not supported customer traits by these endpoints. The SDK rejects unsupported fields. Send arbitrary business data with `trackEvent`; that records event data and does not create custom profile fields.

To update profile fields later, pass `profile`, your application's complete current customer profile object, without email, phone, or userName:

```swift
AlgorithmX.shared.setUserProfile(profile)
```

On logout:

```swift
AlgorithmX.shared.resetIdentity()
```

Logout clears waiting campaigns, generates a fresh anonymous UUID and bootstraps a new anonymous profile. The installation's device UUID is retained. Calling identify with a different account ID also rotates the anonymous UUID first, preventing the two accounts from being merged. Close any campaign already on screen as part of your app's logout flow.

To inspect the SDK-generated UUID for diagnostics:

```swift
let anonymousId = AlgorithmX.shared.getAnonymousId()
```

The SDK remembers the external account ID across restarts. These calls do not replace your application's authentication. API requests are sent in order, but the backend responds with `202 Accepted` and processes messages asynchronously; confirm the stored customer data in AlgorithmX. Offline event/profile requests are dropped. Bootstrap and saved account identification are attempted again on startup/foreground; profile updates must be sent again by your app if delivery failed.

**Check:** the customer can be found using the external ID/email you supplied, and the anonymous UUID is unchanged after login. After logout or switching accounts, it changes.


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
.package(url: "https://github.com/algorithmx-cloud/algorithmx-ios-sdk", from: "1.1.0")
```

### CocoaPods

Install the pod from its Git tag:

```ruby
pod 'AlgorithmXSDK', :git => 'https://github.com/algorithmx-cloud/algorithmx-ios-sdk.git', :tag => '1.1.0'
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

SDK-defined fields and built-in events use camelCase. Manual-preview and visible-push interactions send `fingerprintDevice`, string-valued `campaignId` and `variationId`, `interactionType`, and `payload` to `/api/v1/tracks/algoViewInteract`. Push payloads use keys such as `engageAction`, `algoCampaignId`, `engageVariationId`, `actionType`, `actionButtons`, and `actionText`, with built-in actions such as `algoShowNotification`, `openWebPage`, `openWebview`, `openScreen`, and `customAction`. The WebView bridge accepts `campaignClose`, `campaignClick`, `campaignSubmit`, `campaignCouponCopy`, and `copyCoupon`. Legacy visual push keys, action values, and bridge event names remain accepted; explicit camelCase keys take precedence. Silent-push `algoTriggerWebview` triggers are ignored; in-app campaigns now come from the API.

## SDK HTTP endpoints

API URLs are the initialized `apiBaseUrl` plus the paths below. Every SDK API request includes the `x-partner-id` header containing the initialized partner ID.

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/v1/inAppViews` | Fetch inline in-app campaigns automatically on app open. |
| `POST` | `/api/v1/Identity/Bootstrap` | Bootstrap the SDK-generated anonymous/device UUIDs. |
| `POST` | `/api/v1/Identity` | Link ExternalId, Email, Phone or UserName to the anonymous profile. |
| `POST` | `/api/v1/Customer/Ingest` | Replace supported customer traits. |
| `POST` | `/api/v1/Event/Log` | Send a custom event as an array with its original name and data. |
| `POST` | `/api/v1/tracks/algoViewInteract` | Report campaign and push interactions. |
| `PUT` | `/api/v1/inAppPushEvents/device/status` | Update notification delivery or open status. |
| `POST` | `/api/v1/notificationTokens` | Register a push token for the current customer. |

`trackEvent` keeps the custom name unchanged in `eventType`. General events use `POST /api/v1/Event/Log`, a one-event array body, ISO 8601 UTC timestamps, and `X-Anonymous-Id` containing the SDK-generated anonymous UUID, including after login. `data` contains properties or `{}`; `x-partner-id` is also required. Manual URL-based campaign HTML and notification images are downloaded with `GET` from their supplied URLs, so those downloads have no fixed SDK path. Campaign HTML may also load its own resources. A caller-supplied campaign interaction `endpoint` overrides the default interaction path.

The integration guide covers the full setup: customer identity, events, push notifications, deep links, custom actions, and the notification service extension.

**[iOS integration guide →](https://algorithmx.cloud/en/docs/integrations/ios)**

## License

MIT. See [LICENSE](LICENSE).
