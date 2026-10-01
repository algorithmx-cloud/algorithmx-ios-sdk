# AlgorithmX iOS SDK

Connect your iOS app to [AlgorithmX](https://algorithmx.com), the campaign management and customer data platform. The SDK sends customer identity and events, handles AlgorithmX push notifications, routes campaign actions to your app, and shows in-app campaigns.

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
.package(url: "https://github.com/algorithmx-cloud/algorithmx-ios-sdk", from: "1.0.0")
```

### CocoaPods

Install the pod from its Git tag:

```ruby
pod 'AlgorithmXSDK', :git => 'https://github.com/algorithmx-cloud/algorithmx-ios-sdk.git', :tag => '1.0.0'
```

## Quick start

```swift
import AlgorithmXSDK

// In application(_:didFinishLaunchingWithOptions:)
AlgorithmX.shared.initialize(apiBaseUrl: "https://api.example.com")
```

The integration guide covers the full setup: customer identity, events, push notifications, deep links, custom actions, and the notification service extension.

**[iOS integration guide →](https://algorithmx.com/en/docs/integrations/ios)**

## License

MIT. See [LICENSE](LICENSE).
