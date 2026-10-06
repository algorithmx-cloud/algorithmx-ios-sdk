# Changelog

## 1.0.2

- Fixed notification endpoints now use `/api/v1/inAppPushEvents/device/status` and `/api/v1/notificationTokens` instead of `/api/v1/in-app-push-events/device/status` and `/api/v1/notification-tokens`. The backend must accept the new routes before this SDK release; the local test backend retains the previous routes as aliases. The `x-partner-id` header stays unchanged.
- SDK-defined tracking fields, push fields, built-in events, and action names now use camelCase. Campaign interactions use `/api/v1/tracks/algoViewInteract` and camelCase fields; `payload` remains a JSON string. The backend must support this contract before release.
- Previous fixed push keys/action names and campaign bridge events remain accepted on input. Custom event names, payload keys, nested data, action text, and titles retain their supplied spelling; camelCase is recommended in the guides.
- WebView impression personalization is emitted in a `dynamicContent` object containing the original custom keys and their text values.

## 1.0.1

- **Breaking:** `initialize` takes the partner ID that AlgorithmX gives you: `initialize(apiBaseUrl:partnerId:)` and `initialize(apiBaseUrl:partnerId:appGroup:)`. The SDK, including `EngageNotificationService` in the notification service extension, sends it in the `x-partner-id` header of every request.

## 1.0.0

- First public release of the AlgorithmX iOS SDK (`AlgorithmXSDK`): customer identity, event tracking, APNs token registration, notification routing with deep links, custom actions and buttons, in-app campaigns with display rules, and the notification service extension helper.
