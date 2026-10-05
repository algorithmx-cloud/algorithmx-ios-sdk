# Changelog

## 1.0.1

- **Breaking:** `initialize` takes the partner ID that AlgorithmX gives you: `initialize(apiBaseUrl:partnerId:)` and `initialize(apiBaseUrl:partnerId:appGroup:)`. The SDK, including `EngageNotificationService` in the notification service extension, sends it in the `x-partner-id` header of every request.

## 1.0.0

- First public release of the AlgorithmX iOS SDK (`AlgorithmXSDK`): customer identity, event tracking, APNs token registration, notification routing with deep links, custom actions and buttons, in-app campaigns with display rules, and the notification service extension helper.
